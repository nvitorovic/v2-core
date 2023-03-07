// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { ISablierV2LockupRecipient } from "../../../../src/interfaces/hooks/ISablierV2LockupRecipient.sol";

contract GoodRecipient is ISablierV2LockupRecipient {
    function onStreamCanceled(uint256 streamId, uint128 senderAmount, uint128 recipientAmount) external pure {
        streamId;
        senderAmount;
        recipientAmount;
    }

    function onStreamRenounced(uint256 streamId) external pure {
        streamId;
    }

    function onStreamWithdrawn(uint256 streamId, address caller, address to, uint128 amount) external pure {
        streamId;
        caller;
        to;
        amount;
    }
}
