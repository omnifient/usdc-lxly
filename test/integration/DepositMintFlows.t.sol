// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base} from "../Base.sol";

contract DepositMintFlows is Base {
    function _emitDepositBridgeEvent(
        address receiver,
        uint256 amount
    ) internal {
        emit BridgeEvent(
            1, // _LEAF_TYPE_MESSAGE
            _l1NetworkId, // Deposit always come from L1
            address(_l1Escrow), // from
            _l2NetworkId, // Deposit always targets L2
            address(_minterBurner), // destinationAddress
            0, // msg.value
            abi.encode(receiver, amount), // metadata
            uint32(86512) // ATTN: deposit count in mainnet block 17785773
        );
    }

    /// @notice Alice deposits 1000 L1_USDC to L1Escrow using approve(), and MinterBurner mints back 1000 L2_USDC
    function testDepositToL1EscrowMintsInL2() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 amount = _toUSDC(1000);
        uint256 balance1 = _erc20L1Usdc.balanceOf(_alice);
        _erc20L1Usdc.approve(address(_l1Escrow), amount);

        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitDepositBridgeEvent(_alice, amount);

        // check that our deposit event is emitted
        vm.expectEmit(address(_l1Escrow));
        emit Deposit(_alice, _alice, amount);

        // deposit to L1Escrow
        _l1Escrow.bridgeToken(_alice, amount, true);

        // alice's L1_USDC balance decreased
        uint256 balance2 = _erc20L1Usdc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l1Fork, _l2Fork);

        // alice's L2_USDC balance increased
        vm.selectFork(_l2Fork);
        uint256 balance3 = _erc20L2Usdc.balanceOf(_alice);
        assertEq(balance3, amount);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice deposits 1000 L1_USDC to L1Escrow using permit(), and MinterBurner mints back 1000 L2_USDC
    function testDepositsWithPermit() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 amount = _toUSDC(1000);
        uint256 balance1 = _erc20L1Usdc.balanceOf(_alice);
        bytes memory permitData = _createPermitData(
            _alice,
            address(_l1Escrow),
            _l1Usdc,
            amount
        );

        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitDepositBridgeEvent(_alice, amount);

        // check that our deposit event is emitted
        vm.expectEmit(address(_l1Escrow));
        emit Deposit(_alice, _alice, amount);

        // deposit to L1Escrow
        _l1Escrow.bridgeToken(_alice, amount, true, permitData);

        // alice's L1_USDC balance decreased
        uint256 balance2 = _erc20L1Usdc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l1Fork, _l2Fork);

        // alice's L2_USDC balance increased
        vm.selectFork(_l2Fork);
        uint256 balance3 = _erc20L2Usdc.balanceOf(_alice);
        assertEq(balance3, amount);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice permits a 500 L1_USDC spend but tries to deposit 1000 L1_USDC to L1Escrow.
    function testRevertDepositWithInsufficientPermit() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 approvalAmount = _toUSDC(500);
        uint256 depositAmount = _toUSDC(1000);

        uint256 balance1 = _erc20L1Usdc.balanceOf(_alice);
        bytes memory permitData = _createPermitData(
            _alice,
            address(_l1Escrow),
            _l1Usdc,
            approvalAmount
        );

        // deposit to L1Escrow
        vm.expectRevert(bytes4(0x03fffc4b)); // NotValidAmount()
        _l1Escrow.bridgeToken(_alice, depositAmount, true, permitData);

        // alice's L1_USDC balance is the same
        uint256 balance2 = _erc20L1Usdc.balanceOf(_alice);
        assertEq(balance1, balance2);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice deposits 1000 L1_USDC to L1Escrow for Bob, and MinterBurner mints the L2_USDC accordingly.
    function testDepositToAnotherAddress() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 amount = _toUSDC(1000);
        uint256 balance1 = _erc20L1Usdc.balanceOf(_alice);
        _erc20L1Usdc.approve(address(_l1Escrow), amount);

        // check that a bridge event is emitted
        vm.expectEmit(false, false, false, false, _bridge);
        _emitDepositBridgeEvent(_bob, amount);

        // check that our deposit event is emitted
        vm.expectEmit(address(_l1Escrow));
        emit Deposit(_alice, _bob, amount);

        // deposit to L1Escrow for bob
        _l1Escrow.bridgeToken(_bob, amount, true);

        // alice's L1_USDC balance decreased
        uint256 balance2 = _erc20L1Usdc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // manually trigger the "bridging"
        _claimBridgeMessage(_l1Fork, _l2Fork);

        // alice's L2_USDC balance didn't change
        vm.selectFork(_l2Fork);
        assertEq(_erc20L2Usdc.balanceOf(_alice), 0);

        // but bob's L2_USDC balance increased
        assertEq(_erc20L2Usdc.balanceOf(_bob), amount);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice tries to deposit 0 L1_USDC to L1Escrow.
    function testRevertDepositingZero() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // try to deposit 0 to L1Escrow
        _erc20L1Usdc.approve(address(_l1Escrow), 0);
        vm.expectRevert("INVALID_AMOUNT");
        _l1Escrow.bridgeToken(_alice, 0, true);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice tries to deposit 1000 L1_USDC to L1Escrow for address zero.
    function testRevertDepositingToAddressZero() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // try to deposit 1000 to L1Escrow for address 0
        _erc20L1Usdc.approve(address(_l1Escrow), _toUSDC(1000));
        vm.expectRevert("INVALID_RECEIVER");
        _l1Escrow.bridgeToken(address(0), _toUSDC(1000), true);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice approves a 500 L1_USDC spend but tries to deposit 1000 L1_USDC to L1Escrow.
    function testRevertDepositWithInsufficientApproval() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // setup
        uint256 approvalAmount = _toUSDC(500);
        uint256 depositAmount = _toUSDC(1000);

        uint256 balance1 = _erc20L1Usdc.balanceOf(_alice);
        _erc20L1Usdc.approve(address(_l1Escrow), approvalAmount);

        // deposit to L1Escrow
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        _l1Escrow.bridgeToken(_alice, depositAmount, true);

        // alice's L1_USDC balance is the same
        uint256 balance2 = _erc20L1Usdc.balanceOf(_alice);
        assertEq(balance1, balance2);

        _assertUsdcSupplyAndBalancesMatch();
    }
}
