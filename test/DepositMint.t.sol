// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base} from "./Base.sol";
import "lib/forge-std/src/interfaces/IERC20.sol";

contract DepositMint is Base {
    function testDepositToL1EscrowMintsInL2() public {
        // deposit 1k of L1_USDC to L1Escrow
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);
        uint256 amount = _toUSDC(1000);
        uint256 balance1 = _erc20L1Usdc.balanceOf(_alice);
        _erc20L1Usdc.approve(address(_l1Escrow), amount);
        _l1Escrow.deposit(_alice, amount);
        uint256 balance2 = _erc20L1Usdc.balanceOf(_alice);

        // alice's balance decreased
        assertEq(balance1 - balance2, amount);

        // TODO: message was received by the bridge
        // TODO: deposit event was emitted

        // TODO: sleep a bit?

        // verify that 1k of L2_USDC was minted to alice
        vm.selectFork(_l2Fork);
        uint256 balance3 = _erc20L2Usdc.balanceOf(_alice);
        assertEq(balance3, amount);
    }
}
