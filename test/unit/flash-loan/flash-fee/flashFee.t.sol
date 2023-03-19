// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { UD60x18, ud } from "@prb/math/UD60x18.sol";

import { Errors } from "src/libraries/Errors.sol";

import { FlashLoan_Unit_Test } from "../FlashLoan.t.sol";

contract FlashFee_Unit_Test is FlashLoan_Unit_Test {
    /// @dev it should revert.
    function test_RevertWhen_AssetNotFlashLoanable() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2FlashLoan_AssetNotFlashLoanable.selector, DEFAULT_ASSET));
        flashLoan.flashFee({ asset: address(DEFAULT_ASSET), amount: 0 });
    }

    modifier whenAssetFlashLoanable() {
        comptroller.toggleFlashAsset(DEFAULT_ASSET);
        _;
    }

    /// @dev it should return the correct flash fee.
    function test_FlashFee() external whenAssetFlashLoanable {
        uint256 amount = 782.23e18;
        uint256 actualFlashFee = flashLoan.flashFee({ asset: address(DEFAULT_ASSET), amount: amount });
        uint256 expectedFlashFee = ud(amount).mul(DEFAULT_FLASH_FEE).intoUint256();
        assertEq(actualFlashFee, expectedFlashFee, "flashFee");
    }
}
