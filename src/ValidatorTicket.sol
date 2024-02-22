// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { UUPSUpgradeable } from "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from "openzeppelin-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC20PermitUpgradeable } from "openzeppelin-upgrades/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "openzeppelin/utils/Address.sol";
import { ValidatorTicketStorage } from "src/ValidatorTicketStorage.sol";
import { SafeCast } from "openzeppelin/utils/math/SafeCast.sol";
import { IPufferOracle } from "pufETH/interface/IPufferOracle.sol";
import { IValidatorTicket } from "./interface/IValidatorTicket.sol";

/**
 * @title ValidatorTicket
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract ValidatorTicket is
    IValidatorTicket,
    ValidatorTicketStorage,
    UUPSUpgradeable,
    AccessManagedUpgradeable,
    ERC20PermitUpgradeable
{
    using SafeERC20 for address;
    using Address for address payable;

    /**
     * @inheritdoc IValidatorTicket
     */
    IPufferOracle public immutable override PUFFER_ORACLE;

    /**
     * @inheritdoc IValidatorTicket
     */
    address payable public immutable override GUARDIAN_MODULE;

    /**
     * @inheritdoc IValidatorTicket
     */
    address payable public immutable override PUFFER_VAULT;

    constructor(address payable guardianModule, address payable pufferVault, IPufferOracle pufferOracle) {
        PUFFER_ORACLE = pufferOracle;
        GUARDIAN_MODULE = guardianModule;
        PUFFER_VAULT = pufferVault;
        _disableInitializers();
    }

    function initialize(address accessManager, uint256 treasuryFeeRate, uint256 guardiansFeeRate)
        external
        initializer
    {
        __AccessManaged_init(accessManager);
        __ERC20_init("Puffer Validator Ticket", "VT");
        __ERC20Permit_init("Puffer Validator Ticket");
        _setProtocolFeeRate(treasuryFeeRate);
        _setGuardiansFeeRate(guardiansFeeRate);
    }

    /**
     * @inheritdoc IValidatorTicket
     */
    function purchaseValidatorTicket(address recipient) external payable restricted {
        ValidatorTicket storage $ = _getValidatorTicketStorage();

        uint256 mintPrice = PUFFER_ORACLE.getValidatorTicketPrice();

        // Only a whole VT can be purchased
        if (msg.value % mintPrice != 0) {
            revert InvalidAmount();
        }

        // slither-disable-next-line divide-before-multiply
        _mint(recipient, (msg.value / mintPrice) * 1 ether); // * 1 ether is to upscale amount to 18 decimals

        // If we are over the burst threshold, keep everything
        // That means that pufETH holders are not getting any new rewards until it goes under the threshold
        if (PUFFER_ORACLE.isOverBurstThreshold()) {
            // The remainder belongs to PufferVault
            return;
        }

        // Treasury amount is staying in this contract
        uint256 treasuryAmount = msg.value * $.protocolFeeRate / _ONE_HUNDRED_WAD;
        // Guardians get the cut right away
        uint256 guardiansAmount = _sendETH(GUARDIAN_MODULE, msg.value, $.guardiansFeeRate);
        // The remainder belongs to PufferVault
        uint256 pufferVaultAmount = msg.value - (treasuryAmount + guardiansAmount);
        PUFFER_VAULT.sendValue(pufferVaultAmount);
        emit ETHDispersed({ treasury: treasuryAmount, guardians: guardiansAmount, vault: pufferVaultAmount });
    }

    /**
     * @notice Burns `amount` from the transaction sender
     * @dev Restricted to the PufferProtocol
     * @dev Signature "0x42966c68"
     */
    function burn(uint256 amount) external restricted {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Updates the treasury fee
     * @dev Restricted to the DAO
     * @param newProtocolFeeRate The new treasury fee rate
     */
    function setProtocolFeeRate(uint256 newProtocolFeeRate) external restricted {
        _setProtocolFeeRate(newProtocolFeeRate);
    }

    /**
     * @notice Updates the guardians fee rate
     * @dev Restricted to the DAO
     * @param newGuardiansFeeRate The new guardians fee rate
     */
    function setGuardiansFeeRate(uint256 newGuardiansFeeRate) external restricted {
        _setGuardiansFeeRate(newGuardiansFeeRate);
    }

    /**
     * @inheritdoc IValidatorTicket
     */
    function getProtocolFeeRate() external view returns (uint256) {
        ValidatorTicket storage $ = _getValidatorTicketStorage();
        return $.protocolFeeRate;
    }

    /**
     * @inheritdoc IValidatorTicket
     */
    function getGuardiansFeeRate() external view returns (uint256) {
        ValidatorTicket storage $ = _getValidatorTicketStorage();
        return $.guardiansFeeRate;
    }

    /**
     * @dev This is for sending ETH to trusted addresses (no reentrancy protection)
     * PufferVault, Guardians, Treasury
     */
    function _sendETH(address to, uint256 amount, uint256 rate) internal returns (uint256 toSend) {
        toSend = amount * rate / _ONE_HUNDRED_WAD;

        if (toSend != 0) {
            payable(to).sendValue(toSend);
        }
    }

    function _setProtocolFeeRate(uint256 newProtocolFeeRate) internal {
        ValidatorTicket storage $ = _getValidatorTicketStorage();
        // Treasury fee can not be bigger than 10%
        if ($.protocolFeeRate > (10 * 1 ether)) {
            revert InvalidData();
        }
        uint256 oldProtocolFeeRate = uint256($.protocolFeeRate);
        $.protocolFeeRate = SafeCast.toUint128(newProtocolFeeRate);
        emit ProtocolFeeChanged(oldProtocolFeeRate, newProtocolFeeRate);
    }

    function _setGuardiansFeeRate(uint256 newGuardiansFeeRate) internal {
        ValidatorTicket storage $ = _getValidatorTicketStorage();
        // Treasury fee can not be bigger than 10%
        if ($.protocolFeeRate > (10 * 1 ether)) {
            revert InvalidData();
        }
        uint256 oldGuardiansFeeRate = uint256($.guardiansFeeRate);
        $.guardiansFeeRate = SafeCast.toUint128(newGuardiansFeeRate);
        emit GuardiansFeeChanged(oldGuardiansFeeRate, newGuardiansFeeRate);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}
