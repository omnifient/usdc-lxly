// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base} from "./Base.sol";

contract WithdrawUnlock is Base {
    function _depositToL1Escrow() internal {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);
        uint256 amount = _toUSDC(1000);
        _erc20L1Usdc.approve(address(_l1Escrow), amount);
        _l1Escrow.deposit(_alice, amount);
        _claimBridgeMessage(_l1Fork, _l2Fork);
    }

    function setUp() public override {
        Base.setUp();
        _depositToL1Escrow();
    }

    function _emitWithdrawBridgeEvent(
        address receiver,
        uint256 amount
    ) internal {
        emit BridgeEvent(
            1, // _LEAF_TYPE_MESSAGE
            _l2ChainId, // Withdraw always come from L2
            address(_minterBurner), // from
            _l1ChainId, // Withdraw always targets L1
            address(_l1Escrow), // destinationAddress
            0, // msg.value
            abi.encode(receiver, amount), // metadata
            uint32(86512) // ATTN: deposit count in mainnet block 17785773
        );
    }

    /// @notice Alice has 1000 L2_USDC, withdraws it all, and gets back 1000 L1_USDC
    function testFullWithdrawBurnsAndUnlocksInL1() public {
        // get the initial L1 balance
        vm.selectFork(_l1Fork);
        uint256 l1Balance1 = _erc20L1Usdc.balanceOf(_alice);

        // setup the withdrawal
        vm.selectFork(_l2Fork);
        uint256 amount = _toUSDC(1000);
        _erc20L2Usdc.approve(address(_minterBurner), amount);

        // check that a bridge event is emitted - NOTE: checkData is false
        vm.expectEmit(false, false, false, false, _bridge);
        _emitWithdrawBridgeEvent(_alice, amount);

        // check that our withdrawal event is emitted
        vm.expectEmit(address(_minterBurner));
        emit Withdraw(_alice, _alice, amount);

        // burn the L2_USDC
        _minterBurner.withdraw(_alice, amount);

        // alice's L2_USDC balance is 0
        uint256 l2Balance = _erc20L2Usdc.balanceOf(_alice);
        assertEq(l2Balance, 0);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l2Fork, _l1Fork);

        // alice's L1_USDC balance increased
        vm.selectFork(_l1Fork);
        uint256 l1Balance2 = _erc20L1Usdc.balanceOf(_alice);
        assertEq(l1Balance2 - l1Balance1, amount);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_USDC, withdraws 75%, and gets back 750 L1_USDC
    function testPartialWithdrawBurnsAndUnlocksInL1() public {
        // get the initial L1 balance
        vm.selectFork(_l1Fork);
        uint256 l1Balance1 = _erc20L1Usdc.balanceOf(_alice);

        // setup the withdrawal for 750 L2_USDC
        vm.selectFork(_l2Fork);
        uint256 amount = _toUSDC(750);
        _erc20L2Usdc.approve(address(_minterBurner), amount);

        // check that a bridge event is emitted - NOTE: checkData is false
        vm.expectEmit(false, false, false, false, _bridge);
        _emitWithdrawBridgeEvent(_alice, amount);

        // check that our withdrawal event is emitted
        vm.expectEmit(address(_minterBurner));
        emit Withdraw(_alice, _alice, amount);

        // burn the L2_USDC
        _minterBurner.withdraw(_alice, amount);

        // alice's L2_USDC balance is 1000 - 750 = 250
        uint256 l2Balance = _erc20L2Usdc.balanceOf(_alice);
        assertEq(l2Balance, _toUSDC(250));

        // manually trigger the "bridging"
        _claimBridgeMessage(_l2Fork, _l1Fork);

        // alice's L1_USDC balance increased
        vm.selectFork(_l1Fork);
        uint256 l1Balance2 = _erc20L1Usdc.balanceOf(_alice);
        assertEq(l1Balance2 - l1Balance1, amount);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_USDC, withdraws it all to Bob, who receives 1000 L1_USDC
    function testWithdrawsToAnotherAddress() public {
        // get alice's original L1 balance
        vm.selectFork(_l1Fork);
        uint256 aliceL1Balance = _erc20L1Usdc.balanceOf(_alice);

        // setup the withdrawal
        vm.selectFork(_l2Fork);
        uint256 amount = _toUSDC(1000);
        _erc20L2Usdc.approve(address(_minterBurner), amount);

        // check that a bridge event is emitted - NOTE: checkData is false
        vm.expectEmit(false, false, false, false, _bridge);
        _emitWithdrawBridgeEvent(_bob, amount);

        // check that our withdrawal event is emitted
        vm.expectEmit(address(_minterBurner));
        emit Withdraw(_alice, _bob, amount);

        // withdraw the L2_USDC to bob
        _minterBurner.withdraw(_bob, amount);

        // alice's L2_USDC balance is 0
        uint256 l2Balance = _erc20L2Usdc.balanceOf(_alice);
        assertEq(l2Balance, 0);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l2Fork, _l1Fork);

        // bob's L1_USDC balance increased
        vm.selectFork(_l1Fork);
        uint256 bobL1Balance = _erc20L1Usdc.balanceOf(_bob);
        assertEq(bobL1Balance, amount);

        // alice's L1_USDC balance is the same
        assertEq(_erc20L1Usdc.balanceOf(_alice), aliceL1Balance);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_USDC and tries to withdraw to address 0.
    function testRevertWhenWithdrawingToAddressZero() public {
        // setup
        vm.selectFork(_l2Fork);
        uint256 amount = _toUSDC(1000);
        _erc20L2Usdc.approve(address(_minterBurner), amount);

        // reverts when trying to withdraw the L2_USDC
        vm.expectRevert();
        _minterBurner.withdraw(address(0), amount);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice has 1000 L2_USDC and tries to withdraw 2000 L2_USDC.
    function testRevertWhenWithdrawingMoreThanBalance() public {
        // setup the withdrawal for 2000 L2_USDC
        vm.selectFork(_l2Fork);
        uint256 amount = _toUSDC(2000);
        _erc20L2Usdc.approve(address(_minterBurner), amount);

        // reverts when trying to withdraw the L2_USDC
        vm.expectRevert();
        _minterBurner.withdraw(_alice, amount);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice tries to withdraw 0 L2_USDC.
    function testRevertWhenWithdrawingZero() public {
        // setup the withdrawal for 0 L2_USDC
        vm.selectFork(_l2Fork);
        _erc20L2Usdc.approve(address(_minterBurner), 0);

        // reverts when trying to withdraw zero
        vm.expectRevert();
        _minterBurner.withdraw(_alice, 0);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice approves spending 500 L2_USDC and tries to withdraw 1000 L2_USDC.
    function testRevertWithdrawWithInsufficientApproval() public {
        // setup the withdrawal
        vm.selectFork(_l2Fork);
        uint256 balance1 = _erc20L2Usdc.balanceOf(_alice);

        uint256 approvalAmount = _toUSDC(500);
        uint256 withdrawAmount = _toUSDC(1000);
        _erc20L2Usdc.approve(address(_minterBurner), approvalAmount);

        // try to withdraw the L2_USDC
        vm.expectRevert();
        _minterBurner.withdraw(_alice, withdrawAmount);

        // alice's L2_USDC balance is the same
        uint256 balance2 = _erc20L2Usdc.balanceOf(_alice);
        assertEq(balance1, balance2);

        _assertUsdcSupplyAndBalancesMatch();
    }
}