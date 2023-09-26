// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { PufferServiceManager } from "puffer/PufferServiceManager.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { AbstractVault } from "puffer/AbstractVault.sol";

/**
 * @title ExecutionRewardsVault
 * @notice This is the vault for receiving the execution rewards
 * @author Puffer finance
 * @custom:security-contact security@puffer.fi
 */
contract ExecutionRewardsVault is AbstractVault {
    using SafeTransferLib for address;

    event ExecutionRewardReceived(uint256 amount);

    constructor(PufferServiceManager serviceManager) payable AbstractVault(serviceManager) { }

    receive() external payable {
        emit ExecutionRewardReceived(msg.value);
    }
}