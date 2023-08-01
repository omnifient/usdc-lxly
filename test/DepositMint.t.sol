// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base} from "./Base.sol";
import "lib/forge-std/src/interfaces/IERC20.sol";

contract DepositMint is Base {
    /// @notice Alice deposits 1000 L1_USDC to L1Escrow, and MinterBurner mints back 1000 L2_USDC
    function testDepositToL1EscrowMintsInL2() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 amount = _toUSDC(1000);
        uint256 balance1 = _erc20L1Usdc.balanceOf(_alice);
        _erc20L1Usdc.approve(address(_l1Escrow), amount);

        // check that a bridge event is emitted - NOTE: checkData is false
        vm.expectEmit(false, false, false, false, _bridge);
        emit BridgeEvent(0, 0, address(0), 0, address(0), 0, "", 0);

        // check that our deposit event is emitted
        vm.expectEmit(address(_l1Escrow));
        emit Deposit(_alice, _alice, amount);

        // deposit to L1Escrow
        _l1Escrow.deposit(_alice, amount);

        // alice's L1_USDC balance decreased
        uint256 balance2 = _erc20L1Usdc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l1Fork, _l2Fork);

        // alice's L2_USDC balance increased
        vm.selectFork(_l2Fork);
        uint256 balance3 = _erc20L2Usdc.balanceOf(_alice);
        assertEq(balance3, amount);
    }

    // TODO: test deposit to another address
    // TODO: test deposit reverts if amount is 0
    // TODO: test deposit reverts if address is 0
}
