// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Base} from "../Base.sol";
import "../../src/L1EscrowImpl.sol";
import "../../src/ZkMinterBurnerImpl.sol";
import "../../src/NativeConverterImpl.sol";

contract LxLyHandler is Base {
    address internal _currentActor;

    modifier useActor(uint256 actorIndexSeed) {
        _currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];

        vm.startPrank(_currentActor);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        Base.setUp();

        for (uint i = 0; i < actors.length; i++) {
            address actor = actors[i];
            vm.selectFork(_l1Fork);
            deal(_l1Usdc, actor, _ONE_MILLION_USDC);

            vm.selectFork(_l2Fork);
            deal(_l2Wusdc, actor, _ONE_MILLION_USDC);
        }

        deal(_bridge, 1000000000 ether);
    }

    function deposit(
        uint256 actorIndexSeed,
        address zkReceiver,
        uint256 amount
    ) external useActor(actorIndexSeed) {
        vm.selectFork(_l1Fork);
        bool execBridge = true;

        uint256 l1BalanceBefore = _erc20L1Usdc.balanceOf(_currentActor);
        vm.selectFork(_l2Fork);
        uint256 l2BalanceBefore = _erc20L2Usdc.balanceOf(zkReceiver);
        vm.selectFork(_l1Fork);

        _erc20L1Usdc.approve(address(_l1Escrow), amount);

        if (zkReceiver == address(0)) {
            vm.expectRevert("INVALID_RECEIVER");
            execBridge = false;
        }
        // amount == 0 || amount > balanceOf
        // expectRevert
        else if (amount == 0) {
            vm.expectRevert("INVALID_AMOUNT");
            execBridge = false;
        } else if (amount > _erc20L1Usdc.balanceOf(_currentActor)) {
            vm.expectRevert("ERC20: transfer amount exceeds balance");
            execBridge = false;
        }
        // amount > 0 && amount < balanceOf
        // expectEmit
        else {
            // check that a bridge event is emitted
            vm.expectEmit(_bridge);
            _emitDepositBridgeEvent(zkReceiver, amount);

            // check that our deposit event is emitted
            vm.expectEmit(address(_l1Escrow));
            emit Deposit(_currentActor, zkReceiver, amount);
        }

        // deposit + message to mint
        _l1Escrow.bridgeToken(zkReceiver, amount, true);

        if (execBridge) {
            // check _currentActor's L1_USDC balance decreased
            assertEq(
                l1BalanceBefore - _erc20L1Usdc.balanceOf(_currentActor),
                amount
            );

            // manually trigger the "bridging"
            _claimBridgeMessage(_l1Fork, _l2Fork);

            // check zkReceiver's L2_USDC balance increased
            vm.selectFork(_l2Fork);
            assertEq(
                _erc20L2Usdc.balanceOf(zkReceiver) - l2BalanceBefore,
                amount
            );
        }

        // check main invariant
        _assertUsdcSupplyAndBalancesMatch();
    }

    function withdraw(
        uint256 actorIndexSeed,
        address l1Receiver,
        uint256 amount
    ) external useActor(actorIndexSeed) {
        vm.selectFork(_l2Fork);
        bool execBridge = true;

        uint256 l2BalanceBefore = _erc20L2Usdc.balanceOf(l1Receiver);
        vm.selectFork(_l1Fork);
        uint256 l1BalanceBefore = _erc20L1Usdc.balanceOf(_currentActor);
        vm.selectFork(_l2Fork);

        _erc20L2Usdc.approve(address(_minterBurner), amount);

        if (l1Receiver == address(0)) {
            vm.expectRevert("INVALID_RECEIVER");
            execBridge = false;
        }
        // amount == 0 || amount > balanceOf
        // expectRevert
        else if (amount == 0) {
            vm.expectRevert("FiatToken: burn amount not greater than 0");
            execBridge = false;
        } else if (amount > _erc20L2Usdc.balanceOf(msg.sender)) {
            vm.expectRevert("ERC20: transfer amount exceeds balance");
            execBridge = false;
        }
        // amount > 0 && amount < balanceOf
        // expectEmit
        else {
            // check that a bridge event is emitted
            vm.expectEmit(_bridge);
            _emitWithdrawBridgeEvent(l1Receiver, amount);

            // check that our withdrawal event is emitted
            vm.expectEmit(address(_minterBurner));
            emit Withdraw(_currentActor, l1Receiver, amount);
        }

        // burn + message to withdraw
        _minterBurner.bridgeToken(l1Receiver, amount, true);

        if (execBridge) {
            // check _currentActor's L2_USDC balance decreased
            assertEq(
                l2BalanceBefore - _erc20L2Usdc.balanceOf(_currentActor),
                amount
            );

            // manually trigger the "bridging"
            _claimBridgeMessage(_l2Fork, _l1Fork);

            // check l1Receiver's L1_USDC balance increased
            vm.selectFork(_l1Fork);
            assertEq(
                _erc20L1Usdc.balanceOf(l1Receiver) - l1BalanceBefore,
                amount
            );
        }

        // check main invariant
        _assertUsdcSupplyAndBalancesMatch();
    }

    function convert(
        uint256 actorIndexSeed,
        address receiver,
        uint256 amount
    ) external useActor(actorIndexSeed) {
        vm.selectFork(_l2Fork);
        bool converted = false;

        uint256 senderWUSDCBal = _erc20L2Wusdc.balanceOf(_currentActor);
        uint256 receivedUSDCBal = _erc20L2Usdc.balanceOf(receiver);
        uint256 converterWUSDCBal = _erc20L2Wusdc.balanceOf(
            address(_nativeConverter)
        );

        _erc20L2Wusdc.approve(address(_nativeConverter), amount);

        if (receiver == address(0)) {
            vm.expectRevert("INVALID_RECEIVER");
        }
        // amount == 0 || amount > balanceOf
        // expectRevert
        else if (amount == 0) vm.expectRevert("INVALID_AMOUNT");
        else if (amount > _erc20L2Wusdc.balanceOf(msg.sender)) {
            vm.expectRevert("ERC20: transfer amount exceeds balance");
        }
        // amount > 0 && amount < balanceOf
        // expectEmit
        else {
            converted = true;
            vm.expectEmit(address(_nativeConverter));
            emit Convert(_currentActor, receiver, amount);
        }

        _nativeConverter.convert(receiver, amount);

        if (converted) {
            // check _currentActor's L2_BWUSDC balance decreased
            assertEq(
                senderWUSDCBal - _erc20L2Wusdc.balanceOf(_currentActor),
                amount
            );

            // check receiver's L2_USDC balance increased
            assertEq(
                _erc20L2Usdc.balanceOf(receiver) - receivedUSDCBal,
                amount
            );

            // check _nativeConverter's L2_BWUSDC balance increased
            assertEq(
                _erc20L2Wusdc.balanceOf(address(_nativeConverter)) -
                    converterWUSDCBal,
                amount
            );
        }

        // check main invariant
        _assertUsdcSupplyAndBalancesMatch();
    }

    function migrate(uint256 actorIndexSeed) external useActor(actorIndexSeed) {
        vm.selectFork(_l1Fork);
        uint256 l1BalanceBefore = _erc20L1Usdc.balanceOf(address(_l1Escrow));

        vm.selectFork(_l2Fork);
        bool execBridge = true;

        uint256 amount = _erc20L2Wusdc.balanceOf(address(_nativeConverter));
        if (amount == 0) execBridge = false;
        else {
            // check that a bridge event is emitted
            vm.expectEmit(_bridge);
            _emitMigrateBridgeEvent();

            // check that our migrate event is emitted
            vm.expectEmit(address(_nativeConverter));
            emit Migrate(amount);
        }

        // message to bridge the l2_bwusdc
        _nativeConverter.migrate();

        if (execBridge) {
            // check _nativeConverter L2_BWUSDC balance decreased
            assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), 0);

            // manually trigger the "bridging"
            _claimBridgeAsset(_l2NetworkId, _l1NetworkId);

            // check _l1Escrow L1_USDC balance increased
            vm.selectFork(_l1Fork);
            assertEq(
                _erc20L1Usdc.balanceOf(address(_l1Escrow)) - l1BalanceBefore,
                amount
            );
        }

        // check main invariant
        _assertUsdcSupplyAndBalancesMatch();
    }
}
