// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/Vm.sol";

import {CommonBase} from "lib/forge-std/src/Base.sol";
import {StdCheats} from "lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "lib/forge-std/src/StdUtils.sol";
import {DSTest} from "lib/forge-std/src/Test.sol";

import {Events} from "../Base.sol";
import "../../src/mocks/MockBridge.sol";
import "../../src/L1EscrowImpl.sol";
import "../../src/ZkMinterBurnerImpl.sol";
import "../../src/NativeConverterImpl.sol";

enum Operation {
    NOOP,
    DEPOSITING,
    WITHDRAWING,
    CONVERTING,
    MIGRATING
}

enum FuzzyFunding {
    NO_FUND,
    SAME_AMOUNT,
    GREATER_AMOUNT
}

contract HandlerState {
    Vm private _vm;
    uint256 private _stateFork;

    Operation internal _currentOp;
    bool public continueExecution;
    address internal _fuzzedReceiver;
    uint256 internal _fuzzedAmount;
    uint256 internal _l1BalanceBefore;
    uint256 internal _l2BalanceBefore;
    uint256 internal _senderWUSDCBal;
    uint256 internal _receiverUSDCBal;
    uint256 internal _converterWUSDCBal;

    constructor(Vm vm, uint256 stateFork) {
        _vm = vm;
        _stateFork = stateFork;
    }

    modifier useStateFork() {
        uint256 currentFork = _vm.activeFork();
        if (currentFork != _stateFork) _vm.selectFork(_stateFork);
        _;
        if (currentFork != _stateFork) _vm.selectFork(currentFork);
    }

    // "IOperator"

    function setNoOp() public useStateFork {
        _currentOp = Operation.NOOP;
    }

    function setDepositing() public useStateFork {
        _currentOp = Operation.DEPOSITING;
    }

    function setWithdrawing() public useStateFork {
        _currentOp = Operation.WITHDRAWING;
    }

    function setConverting() public useStateFork {
        _currentOp = Operation.CONVERTING;
    }

    function setMigrating() public useStateFork {
        _currentOp = Operation.MIGRATING;
    }

    // getters & setters for state

    function setContinueExecution(bool exec) external useStateFork {
        continueExecution = exec;
    }

    function setReceiver(address receiver) external useStateFork {
        _fuzzedReceiver = receiver;
    }

    function setAmount(uint256 amount) external useStateFork {
        _fuzzedAmount = amount;
    }

    function setBalancesBefores(uint256 l1, uint256 l2) external useStateFork {
        _l1BalanceBefore = l1;
        _l2BalanceBefore = l2;
    }

    function setBalances(
        uint256 sender,
        uint256 receiver,
        uint256 converter
    ) external useStateFork {
        _senderWUSDCBal = sender;
        _receiverUSDCBal = receiver;
        _converterWUSDCBal = converter;
    }

    function getCurrentOp() external useStateFork returns (Operation) {
        return _currentOp;
    }

    function getState()
        external
        useStateFork
        returns (
            bool,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            continueExecution,
            _fuzzedReceiver,
            _fuzzedAmount,
            _l1BalanceBefore,
            _l2BalanceBefore,
            _senderWUSDCBal,
            _receiverUSDCBal,
            _converterWUSDCBal
        );
    }
}

contract LxLyHandler is CommonBase, StdCheats, StdUtils, DSTest {
    address public currentActor;

    HandlerState internal _state;

    uint256 internal _l1Fork;
    uint256 internal _l2Fork;
    uint32 internal _l1NetworkId;
    uint32 internal _l2NetworkId;
    address[] internal _actors;
    address internal _bridge;
    IERC20 internal _erc20L1Usdc;
    IERC20 internal _erc20L2Usdc;
    IERC20 internal _erc20L2Wusdc;
    L1EscrowImpl internal _l1Escrow;
    NativeConverterImpl internal _nativeConverter;
    ZkMinterBurnerImpl internal _minterBurner;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors[bound(actorIndexSeed, 0, _actors.length - 1)];

        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(
        uint256 l1Fork,
        uint256 l2Fork,
        uint32 l1NetworkId,
        uint32 l2NetworkId,
        address[] memory actors,
        address bridge,
        IERC20 erc20L1Usdc,
        IERC20 erc20L2Usdc,
        IERC20 erc20L2Wusdc
    ) {
        _l1Fork = l1Fork;
        _l2Fork = l2Fork;
        _l1NetworkId = l1NetworkId;
        _l2NetworkId = l2NetworkId;
        _actors = actors;
        _bridge = bridge;
        _erc20L1Usdc = erc20L1Usdc;
        _erc20L2Usdc = erc20L2Usdc;
        _erc20L2Wusdc = erc20L2Wusdc;
    }

    function init(
        HandlerState state,
        L1EscrowImpl l1Escrow,
        NativeConverterImpl nativeConverter,
        ZkMinterBurnerImpl minterBurner
    ) external {
        _state = state;
        _l1Escrow = l1Escrow;
        _nativeConverter = nativeConverter;
        _minterBurner = minterBurner;
    }

    // HANDLER FUNCTIONS

    function deposit(
        uint256 actorIndexSeed,
        uint256 fundingIndexSeed,
        address zkReceiver,
        uint256 amount
    ) external useActor(actorIndexSeed) {
        // fuzz the balance of the currentActor to [0|amount|amount+1]
        fuzzActorBalance(
            fundingIndexSeed,
            amount,
            _l1Fork,
            address(_erc20L1Usdc),
            currentActor
        );

        _state.setDepositing();
        _state.setContinueExecution(true);
        _state.setAmount(amount);
        _state.setReceiver(zkReceiver);
        _state.setBalancesBefores(
            _getL1USDCBalance(currentActor),
            _getL2USDCBalance(zkReceiver)
        );

        vm.selectFork(_l1Fork);
        _erc20L1Usdc.approve(address(_l1Escrow), amount);

        if (zkReceiver == address(0)) {
            _state.setContinueExecution(false);
            vm.expectRevert("INVALID_RECEIVER");
        }
        // amount == 0 || amount > balanceOf
        // expectRevert
        else if (amount == 0) {
            _state.setContinueExecution(false);
            vm.expectRevert("INVALID_AMOUNT");
        } else if (amount > _getL1USDCBalance(currentActor)) {
            _state.setContinueExecution(false);
            vm.expectRevert("ERC20: transfer amount exceeds balance");
        }
        // amount > 0 && amount < balanceOf
        // expectEmit
        else {
            // check that a bridge event is emitted
            vm.expectEmit(_bridge);
            emit Events.BridgeEvent(
                1, // _LEAF_TYPE_MESSAGE
                _l1NetworkId, // Deposit always come from L1
                address(_l1Escrow), // from
                _l2NetworkId, // Deposit always targets L2
                address(_minterBurner), // destinationAddress
                0, // msg.value
                abi.encode(zkReceiver, amount), // metadata
                uint32(MockBridge(_bridge).depositCount())
            );

            // check that our deposit event is emitted
            vm.expectEmit(address(_l1Escrow));
            emit Events.Deposit(currentActor, zkReceiver, amount);
        }

        // deposit + message to mint
        _l1Escrow.bridgeToken(zkReceiver, amount, true);
    }

    function withdraw(
        uint256 actorIndexSeed,
        address l1Receiver,
        uint256 amount
    ) external useActor(actorIndexSeed) {
        // NOTE: we are not fuzzing the balance in the withdraw because
        // it requires creating L2_USDC
        // that means either changing the totalSupply without the equivalent
        // L1_USDC/L2_WUSDC or funding those tokens to the required contracts

        _state.setWithdrawing();
        _state.setContinueExecution(true);
        _state.setAmount(amount);
        _state.setReceiver(l1Receiver);
        _state.setBalancesBefores(
            _getL1USDCBalance(currentActor),
            _getL2USDCBalance(l1Receiver)
        );

        vm.selectFork(_l2Fork);
        _erc20L2Usdc.approve(address(_minterBurner), amount);

        if (l1Receiver == address(0)) {
            _state.setContinueExecution(false);
            vm.expectRevert("INVALID_RECEIVER");
        }
        // amount == 0 || amount > balanceOf
        // expectRevert
        else if (amount == 0) {
            _state.setContinueExecution(false);
            vm.expectRevert("FiatToken: burn amount not greater than 0");
        } else if (amount > _getL2USDCBalance(currentActor)) {
            _state.setContinueExecution(false);
            vm.expectRevert("ERC20: transfer amount exceeds balance");
        }
        // amount > 0 && amount < balanceOf
        // expectEmit
        else {
            // check that a bridge event is emitted
            vm.expectEmit(_bridge);
            emit Events.BridgeEvent(
                1, // _LEAF_TYPE_MESSAGE
                _l2NetworkId, // Withdraw always come from L2
                address(_minterBurner), // from
                _l1NetworkId, // Withdraw always targets L1
                address(_l1Escrow), // destinationAddress
                0, // msg.value
                abi.encode(l1Receiver, amount), // metadata
                uint32(MockBridge(_bridge).depositCount())
            );

            // check that our withdrawal event is emitted
            vm.expectEmit(address(_minterBurner));
            emit Events.Withdraw(currentActor, l1Receiver, amount);
        }

        // burn + message to withdraw
        _minterBurner.bridgeToken(l1Receiver, amount, true);
    }

    function convert(
        uint256 actorIndexSeed,
        uint256 fundingIndexSeed,
        address receiver,
        uint256 amount
    ) external useActor(actorIndexSeed) {
        // fuzz the balance of the currentActor to [0|amount|amount+1]
        fuzzActorBalance(
            fundingIndexSeed,
            amount,
            _l2Fork,
            address(_erc20L2Wusdc),
            currentActor
        );

        _state.setConverting();
        _state.setContinueExecution(false);
        _state.setAmount(amount);
        _state.setReceiver(receiver);
        _state.setBalances(
            _getL2WUSDCBalance(currentActor),
            _getL2USDCBalance(receiver),
            _getL2WUSDCBalance(address(_nativeConverter))
        );

        vm.selectFork(_l2Fork);
        _erc20L2Wusdc.approve(address(_nativeConverter), amount);

        if (receiver == address(0)) {
            vm.expectRevert("INVALID_RECEIVER");
        }
        // amount == 0 || amount > balanceOf
        // expectRevert
        else if (amount == 0) {
            vm.expectRevert("INVALID_AMOUNT");
        } else if (amount > _getL2WUSDCBalance(currentActor)) {
            vm.expectRevert("ERC20: transfer amount exceeds balance");
        }
        // amount > 0 && amount < balanceOf
        // expectEmit
        else {
            _state.setContinueExecution(true);
            vm.expectEmit(address(_nativeConverter));
            emit Events.Convert(currentActor, receiver, amount);
        }

        bytes memory emptyPermitData;
        _nativeConverter.convert(receiver, amount, emptyPermitData);
    }

    function migrate(uint256 actorIndexSeed) external useActor(actorIndexSeed) {
        _state.setMigrating();
        _state.setBalancesBefores(_getL1USDCBalance(address(_l1Escrow)), 0);
        _state.setContinueExecution(true);

        vm.selectFork(_l2Fork);
        uint256 amount = _getL2WUSDCBalance(address(_nativeConverter));
        _state.setAmount(amount);

        // we must fund the bridge with L1_USDC with the same amount of L2_WUSDC we are migrating
        // because this is our mock bridge, whereas the real bridge has L1_USDC locked in it
        deal(address(_erc20L1Usdc), _bridge, amount);

        if (amount == 0) {
            _state.setContinueExecution(false);
        } else {
            // check that a bridge event is emitted
            vm.expectEmit(_bridge);
            emit Events.BridgeEvent(
                0, // _LEAF_TYPE_ASSET
                _l1NetworkId, // originNetwork is the origin network of the underlying asset
                address(_erc20L1Usdc), // originTokenAddress
                _l1NetworkId, // Migrate always targets L2
                address(_l1Escrow), // destinationAddress
                amount, // amount
                "", // metadata is empty when bridging wrapped assets
                uint32(MockBridge(_bridge).depositCount())
            );

            // check that our migrate event is emitted
            vm.expectEmit(address(_nativeConverter));
            emit Events.Migrate(amount);
        }

        // message to bridge the l2_bwusdc
        _nativeConverter.migrate();
    }

    // HELPERS

    function fuzzActorBalance(
        uint256 fundingSeed,
        uint256 amount,
        uint256 forkId,
        address token,
        address actor
    ) internal {
        FuzzyFunding ff = FuzzyFunding(bound(fundingSeed, 0, 2));

        // cap the max funding amount because USDC has a limit
        uint256 MAX_FUNDING = 10 ** 12; // type(uint256).max;
        if (amount > MAX_FUNDING) amount = MAX_FUNDING;

        uint256 fundingAmount = 0;
        if (ff == FuzzyFunding.SAME_AMOUNT) {
            fundingAmount = amount;
        } else if (ff == FuzzyFunding.GREATER_AMOUNT) {
            fundingAmount = amount + 1;
        } else {
            assert(ff == FuzzyFunding.NO_FUND);
        }

        vm.selectFork(forkId);
        deal(token, actor, fundingAmount);
    }

    // BALANCE HELPERS

    modifier useFork(uint256 fork) {
        uint256 currentFork = vm.activeFork();
        if (currentFork != fork) vm.selectFork(fork);
        _;
        if (currentFork != fork) vm.selectFork(currentFork);
    }

    function _getL1USDCBalance(
        address addr
    ) internal useFork(_l1Fork) returns (uint256) {
        return _erc20L1Usdc.balanceOf(addr);
    }

    function _getL2USDCBalance(
        address addr
    ) internal useFork(_l2Fork) returns (uint256) {
        return _erc20L2Usdc.balanceOf(addr);
    }

    function _getL2WUSDCBalance(
        address addr
    ) internal useFork(_l2Fork) returns (uint256) {
        return _erc20L2Wusdc.balanceOf(addr);
    }
}
