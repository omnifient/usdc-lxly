// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base} from "../Base.sol";

contract SecurityFlows is Base {
    /// @notice Calling L1Escrow.onMessageReceived fails
    function testRevertCallingL1EscrowOnMessageReceived() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // call with valid parameters
        bytes memory data = abi.encode(_alice, _toUSDC(1000));
        vm.expectRevert("NOT_BRIDGE");
        _l1Escrow.onMessageReceived(address(_minterBurner), _l1NetworkId, data);
    }

    /// @notice Calling ZkMinterBurner.onMessageReceived fails
    function testRevertCallingMinterBurnerOnMessageReceived() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // call with valid parameters
        bytes memory data = abi.encode(_alice, _toUSDC(1000));
        vm.expectRevert("NOT_BRIDGE");
        _minterBurner.onMessageReceived(address(_l1Escrow), _l2NetworkId, data);
    }

    /// @notice Calling L1Escrow.initialize without being an admin fails
    function testRevertAliceInitializeL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        // it's initialized
        assertNotEq(address(_l1Escrow.bridge()), address(0));

        // can't initialize because already initialized
        vm.expectRevert("Initializable: contract is already initialized");
        _l1Escrow.initialize(
            address(0),
            address(0),
            _l2NetworkId,
            address(0),
            address(0)
        );
    }

    /// @notice Calling ZkMinterBurner.initialize without being an admin fails
    function testRevertAliceInitializeMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // it's initialized
        assertNotEq(address(_minterBurner.bridge()), address(0));

        // can't initialize because already initialized
        vm.expectRevert("Initializable: contract is already initialized");
        _minterBurner.initialize(
            address(0),
            address(0),
            _l1NetworkId,
            address(0),
            address(0)
        );
    }

    /// @notice Calling NativeConverter.initialize without being an admin fails
    function testRevertAliceInitializeNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // it's initialized
        assertNotEq(address(_nativeConverter.bridge()), address(0));

        // can't initialize because already initialized
        vm.expectRevert("Initializable: contract is already initialized");
        _nativeConverter.initialize(
            address(0),
            address(0),
            _l1NetworkId,
            address(0),
            address(0),
            address(0)
        );
    }
}
