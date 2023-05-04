// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Lockup_Shared_Test } from "../../../shared/lockup/Lockup.t.sol";

abstract contract StreamedAmountOf_Shared_Test is Lockup_Shared_Test {
    uint256 internal defaultStreamId;

    function setUp() public virtual override {
        defaultStreamId = createDefaultStream();
    }

    modifier whenNotNull() {
        _;
    }

    modifier whenStreamHasBeenCanceled() {
        _;
    }

    modifier whenStreamHasNotBeenCanceled() {
        _;
    }

    modifier whenStatusStreaming() {
        _;
    }

    modifier whenStartTimeInThePast() {
        _;
    }
}
