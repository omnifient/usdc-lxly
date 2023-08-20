// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Test.sol";

import {HandlerState, LxLyHandler, Operation} from "./LxLyHandler.sol";
import {Base} from "../Base.sol";
import "./InvMockBridge.sol";

contract Supply is Base {
    HandlerState private _state;
    LxLyHandler private _handler;

    function setUp() public override {
        // initialize base
        super.setUp();
        super._fundActors();

        // create and init the handler
        _state = new HandlerState(vm, _l1Fork);
        address stateAddr = address(_state);

        _handler = new LxLyHandler(
            _l1Fork,
            _l2Fork,
            _l1NetworkId,
            _l2NetworkId,
            _actors,
            _bridge,
            _erc20L1Usdc,
            _erc20L2Usdc,
            _erc20L2Wusdc
        );
        _handler.init(_state, _l1Escrow, _nativeConverter, _minterBurner);
        address handlerAddr = address(_handler);

        vm.makePersistent(stateAddr);
        vm.makePersistent(handlerAddr);

        // register the actors
        targetSender(_actors[0]);
        targetSender(_actors[1]);
        targetSender(_actors[2]);
        targetSender(_actors[3]);
        targetSender(_actors[4]);
        targetSender(_actors[5]);
        targetSender(_actors[6]);

        // register the selectors
        bytes4[] memory selectors = new bytes4[](2);
        // selectors[0] = _handler.deposit.selector;
        // selectors[1] = _handler.withdraw.selector;
        selectors[0] = _handler.convert.selector;
        selectors[1] = _handler.migrate.selector;
        targetSelector(FuzzSelector({addr: handlerAddr, selectors: selectors}));

        // register the contract
        targetContract(handlerAddr);

        excludeContract(_bridge);
        excludeContract(stateAddr);
    }

    function _deployMockBridge() internal override {
        console.log("....... deploying mock bridge");
        // TODO: TBI
        bytes32 salt = "LXLY_BRIDGE";

        vm.selectFork(_l1Fork);
        InvMockBridge b1 = new InvMockBridge{salt: salt}(vm, _bridge);
        address b1Addr = address(b1);
        // b1.initialize(_l1NetworkId, vm, address(0), address(0), 0, address(0));
        // fund it with L1_USDC
        deal(_l1Usdc, b1Addr, 1000000 * _ONE_MILLION_USDC);

        vm.selectFork(_l2Fork);
        InvMockBridge b2 = new InvMockBridge{salt: salt}(vm, _bridge);
        address b2Addr = address(b2);
        // b2.initialize(
        //     _l2NetworkId,
        //     vm,
        //     _bridge,
        //     _l2Wusdc,
        //     _l1NetworkId,
        //     _l1Usdc
        // );
        (uint32 xx, address yy) = b2.wrappedTokenToTokenInfo(_l2Wusdc);
        console.log("hey!", yy);
        // fund it with L2_WUSDC
        // deal(_l2Wusdc, b2Addr, 1000000 * _ONE_MILLION_USDC);

        assert(b1Addr == b2Addr);
        _bridge = b1Addr;

        console.log("....... deployed mock bridge");
    }

    // the test

    function invariantGigaTest() public {
        console.log("-------- invariantGigaTest");

        uint256 currentFork = vm.activeFork();
        vm.selectFork(_l1Fork);
        console.log(
            "GIGA: l1Escrow's L1USDC balance: %s",
            _erc20L1Usdc.balanceOf(address(_l1Escrow))
        );
        vm.selectFork(currentFork);

        // TODO: assertUpgradeConditionals();
    }

    // helpers

    function _assertDepositConditionals() private {
        (
            bool continueExecution,
            address receiver,
            uint256 amount,
            uint256 l1BalanceBefore,
            uint256 l2BalanceBefore,
            ,
            ,

        ) = _state.getState();

        if (continueExecution) {
            // check currentActor's L1_USDC balance decreased
            vm.selectFork(_l1Fork);
            assertEq(
                l1BalanceBefore -
                    _erc20L1Usdc.balanceOf(_handler.currentActor()),
                amount
            );

            // manually trigger the "bridging"
            _claimBridgeMessage(_l1Fork, _l2Fork);

            // check zkReceiver's L2_USDC balance increased
            vm.selectFork(_l2Fork);
            assertEq(
                _erc20L2Usdc.balanceOf(receiver) - l2BalanceBefore,
                amount
            );

            // check main invariant
            _assertUsdcSupplyAndBalancesMatch();
        }
    }

    function _assertWithdrawConditionals() private {
        (
            bool continueExecution,
            address receiver,
            uint256 amount,
            uint256 l1BalanceBefore,
            uint256 l2BalanceBefore,
            ,
            ,

        ) = _state.getState();

        if (continueExecution) {
            // check currentActor's L2_USDC balance decreased
            vm.selectFork(_l2Fork);
            assertEq(
                l2BalanceBefore -
                    _erc20L2Usdc.balanceOf(_handler.currentActor()),
                amount
            );

            // manually trigger the "bridging"
            _claimBridgeMessage(_l2Fork, _l1Fork);

            // check l1Receiver's L1_USDC balance increased
            vm.selectFork(_l1Fork);
            assertEq(
                _erc20L1Usdc.balanceOf(receiver) - l1BalanceBefore,
                amount
            );

            // check main invariant
            _assertUsdcSupplyAndBalancesMatch();
        }
    }

    function _assertConvertConditionals() private {
        (
            bool continueExecution,
            address receiver,
            uint256 amount,
            ,
            ,
            uint256 senderWUSDCBal,
            uint256 receiverUSDCBal,
            uint256 converterWUSDCBal
        ) = _state.getState();

        if (continueExecution) {
            vm.selectFork(_l2Fork);

            // check currentActor's L2_BWUSDC balance decreased
            assertEq(
                senderWUSDCBal -
                    _erc20L2Wusdc.balanceOf(_handler.currentActor()),
                amount
            );

            // check receiver's L2_USDC balance increased
            assertEq(
                _erc20L2Usdc.balanceOf(receiver) - receiverUSDCBal,
                amount
            );

            // check _nativeConverter's L2_BWUSDC balance increased
            assertEq(
                _erc20L2Wusdc.balanceOf(address(_nativeConverter)) -
                    converterWUSDCBal,
                amount
            );

            // check main invariant
            _assertUsdcSupplyAndBalancesMatch();
        }
    }

    function _assertMigrateConditionals() private {
        (
            bool continueExecution,
            ,
            uint256 amount,
            uint256 l1BalanceBefore,
            ,
            ,
            ,

        ) = _state.getState();

        if (continueExecution) {
            // check _nativeConverter L2_BWUSDC balance decreased
            vm.selectFork(_l2Fork);
            assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), 0);

            // manually trigger the "bridging"
            _claimBridgeAsset(_l2NetworkId, _l1NetworkId);

            // check _l1Escrow L1_USDC balance increased
            vm.selectFork(_l1Fork);
            assertEq(
                _erc20L1Usdc.balanceOf(address(_l1Escrow)) - l1BalanceBefore,
                amount
            );

            // check main invariant
            _assertUsdcSupplyAndBalancesMatch();
        }
    }
}
