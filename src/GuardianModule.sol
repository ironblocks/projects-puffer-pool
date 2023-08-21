// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Safe } from "safe-contracts/Safe.sol";
import { SafeStorage } from "safe-contracts/libraries/SafeStorage.sol";
import { Enum } from "safe-contracts/common/Enum.sol";
import { Initializable } from "openzeppelin/proxy/utils/Initializable.sol";
import { IGuardianModule } from "puffer/interface/IGuardianModule.sol";
import { PufferPool } from "puffer/PufferPool.sol";

/**
 * @title Guardian module
 * @author Puffer finance
 * @dev This contract is both {Safe} module, and a logic contract to be called via `delegatecall` from {Safe} (GuardianAccount)
 * @custom:security-contact security@puffer.fi
 */
contract GuardianModule is SafeStorage, Initializable, IGuardianModule {
    PufferPool public immutable pool;
    address public immutable myAddress;
    address internal constant SENTINEL_MODULES = address(0x1);

    /**
     * @notice This seed is representing a mappin glike this: mapping(address guardian => address guardianEnclave);
     *         We are storing this mapping data in PodAccount's unstructured storage
     * @dev uint256(keccak256("puffer.guardian.keys"))
     */
    uint256 public constant GUARDIAN_KEYS_SEED =
        21179069603049101978888635358919905010850171584254878123552458168785430937385;

    constructor(PufferPool pufferPool) {
        pool = pufferPool;
        myAddress = address(this);
    }

    /**
     * @inheritdoc IGuardianModule
     */
    function rotateGuardianKey(
        address guardianAccount,
        uint256 blockNumber,
        bytes calldata pubKey,
        bytes calldata raveEvidence
    ) external {
        Safe safe = Safe(payable(guardianAccount));
        // Because this is called from the safe via .delegateCall
        // address(this) equals to {Safe}
        // This will revert if the caller is not one of the {Safe} owners
        if (!safe.isOwner(msg.sender)) {
            revert Unauthorized();
        }

        safe.execTransactionFromModule({
            to: address(this),
            value: 0,
            data: abi.encodeCall(GuardianModule.rotateKey, (msg.sender, blockNumber, pubKey[1:], raveEvidence)),
            operation: Enum.Operation.DelegateCall
        });
    }

    /**
     * @notice This function is supposed to be called via delegatecall from "rotateGuardianKey"
     * @dev DO NOT CALL THIS FUNCTION
     */
    function rotateKey(address guardian, uint256 blockNumber, bytes calldata pubKey, bytes calldata raveEvidence)
        external
    {
        address computedAddress = address(uint160(uint256(keccak256(pubKey))));

        assembly {
            mstore(0x0c, GUARDIAN_KEYS_SEED)
            mstore(0x00, guardian)
            let storageSlot := keccak256(0x0c, 0x20)
            sstore(storageSlot, computedAddress)
        }

        emit RotatedGuardianKey(guardian, computedAddress, pubKey);
    }

    /**
     * @inheritdoc IGuardianModule
     */
    function isGuardiansEnclaveAddress(address payable guardianAccount, address guardian, address enclave)
        external
        view
        returns (bool)
    {
        // Assert if the stored enclaveAddress equals enclave
        return _getGuardianEnclaveAddress(Safe(guardianAccount), guardian) == enclave;
    }

    function _getGuardianEnclaveAddress(Safe guardianAccount, address guardian) internal view returns (address) {
        // Compute the storage slot
        uint256 storageSlot;
        assembly ("memory-safe") {
            mstore(0x0c, GUARDIAN_KEYS_SEED)
            mstore(0x00, guardian)
            storageSlot := keccak256(0x0c, 0x20)
        }

        // Read storage slot from the {Safe}
        bytes memory result = guardianAccount.getStorageAt(storageSlot, 1);

        // Decode it to bytes32
        bytes32 data = abi.decode(result, (bytes32));

        // Return the address
        return address(uint160(uint256(data)));
    }

    function getGuardiansEnclaveAddresses(Safe guardianAccount) external view returns (address[] memory) {
        address[] memory guardians = guardianAccount.getOwners();
        address[] memory enclaveAddresses = new address[](guardians.length);

        for (uint256 i = 0; i < guardians.length;) {
            enclaveAddresses[i] = _getGuardianEnclaveAddress(guardianAccount, guardians[i]);
            unchecked {
                ++i;
            }
        }

        return enclaveAddresses;
    }

    /**
     * @notice Enable this module on {Safe} creation
     */
    function enableMyself() public {
        // Only DelegateCall should work
        require(myAddress != address(this));

        // Module cannot be added twice.
        require(modules[myAddress] == address(0), "GS102");
        modules[myAddress] = modules[SENTINEL_MODULES];
        modules[SENTINEL_MODULES] = myAddress;
    }
}
