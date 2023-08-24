// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base} from "../Base.sol";
import "../../src/L1EscrowImpl.sol";
import "../../src/NativeConverterImpl.sol";
import "../../src/ZkMinterBurnerImpl.sol";

contract OwnerOperationsFlows is Base {
    event Upgraded(address indexed implementation);

    /// @notice Admin can upgrade contracts to a valid address.

    function testAdminCanUpgradeL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_deployerOwnerAdmin);

        L1EscrowImpl newImpl = new L1EscrowImpl();
        address newImplAddr = address(newImpl);

        vm.expectEmit(address(_l1Escrow));
        emit Upgraded(newImplAddr);
        _l1Escrow.upgradeTo(newImplAddr);
    }

    function testAdminCanUpgradeMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_deployerOwnerAdmin);

        ZkMinterBurnerImpl newImpl = new ZkMinterBurnerImpl();
        address newImplAddr = address(newImpl);

        vm.expectEmit(address(_minterBurner));
        emit Upgraded(newImplAddr);
        _minterBurner.upgradeTo(newImplAddr);
    }

    function testAdminCanUpgradeNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_deployerOwnerAdmin);

        NativeConverterImpl newImpl = new NativeConverterImpl();
        address newImplAddr = address(newImpl);

        vm.expectEmit(address(_nativeConverter));
        emit Upgraded(newImplAddr);
        _nativeConverter.upgradeTo(newImplAddr);
    }

    /// @notice Non-Admin cannot upgrade contracts.

    function testRevertNonAdminCannotUpgradeL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        L1EscrowImpl newImpl = new L1EscrowImpl();
        address newImplAddr = address(newImpl);

        vm.expectRevert("NOT_ADMIN");
        _l1Escrow.upgradeTo(newImplAddr);
    }

    function testRevertNonAdminCannotUpgradeMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        ZkMinterBurnerImpl newImpl = new ZkMinterBurnerImpl();
        address newImplAddr = address(newImpl);

        vm.expectRevert("NOT_ADMIN");
        _minterBurner.upgradeTo(newImplAddr);
    }

    function testRevertNonAdminCannotUpgradeNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        NativeConverterImpl newImpl = new NativeConverterImpl();
        address newImplAddr = address(newImpl);

        vm.expectRevert("NOT_ADMIN");
        _nativeConverter.upgradeTo(newImplAddr);
    }

    /// @notice Owner can pause and unpause contracts.

    function testOwnerCanPauseUnpauseL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_deployerOwnerAdmin);

        assertEq(_l1Escrow.paused(), false);
        _l1Escrow.pause();
        assertEq(_l1Escrow.paused(), true);
        _l1Escrow.unpause();
        assertEq(_l1Escrow.paused(), false);
    }

    function testOwnerCanPauseUnpauseMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_deployerOwnerAdmin);

        assertEq(_minterBurner.paused(), false);
        _minterBurner.pause();
        assertEq(_minterBurner.paused(), true);
        _minterBurner.unpause();
        assertEq(_minterBurner.paused(), false);
    }

    function testOwnerCanPauseUnpauseNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_deployerOwnerAdmin);

        assertEq(_nativeConverter.paused(), false);
        _nativeConverter.pause();
        assertEq(_nativeConverter.paused(), true);
        _nativeConverter.unpause();
        assertEq(_nativeConverter.paused(), false);
    }

    /// @notice Contracts are unpaused, a non-owner tries to pause them, but it reverts.

    function testRevertNonOwnerCannotPauseL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_alice);

        assertEq(_l1Escrow.paused(), false);
        vm.expectRevert("Ownable: caller is not the owner");
        _l1Escrow.pause();
        assertEq(_l1Escrow.paused(), false);
    }

    function testRevertNonOwnerCannotPauseMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        assertEq(_minterBurner.paused(), false);
        vm.expectRevert("Ownable: caller is not the owner");
        _minterBurner.pause();
        assertEq(_minterBurner.paused(), false);
    }

    function testRevertNonOwnerCannotPauseNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        assertEq(_nativeConverter.paused(), false);
        vm.expectRevert("Ownable: caller is not the owner");
        _nativeConverter.pause();
        assertEq(_nativeConverter.paused(), false);
    }

    /// @notice Contracts are paused, a non-owner tries to unpause them, but it reverts.

    function testRevertNonOwnerCannotPauseUnpauseL1Escrow() public {
        vm.selectFork(_l1Fork);
        vm.startPrank(_deployerOwnerAdmin);
        _l1Escrow.pause();
        assertEq(_l1Escrow.paused(), true);

        changePrank(_alice);
        vm.expectRevert("Ownable: caller is not the owner");
        _l1Escrow.unpause();
        assertEq(_l1Escrow.paused(), true);
    }

    function testRevertNonOwnerCannotPauseUnpauseMinterBurner() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_deployerOwnerAdmin);
        _minterBurner.pause();
        assertEq(_minterBurner.paused(), true);

        changePrank(_alice);
        vm.expectRevert("Ownable: caller is not the owner");
        _minterBurner.unpause();
        assertEq(_minterBurner.paused(), true);
    }

    function testRevertNonOwnerCannotPauseUnpauseNativeConverter() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_deployerOwnerAdmin);
        _nativeConverter.pause();
        assertEq(_nativeConverter.paused(), true);

        changePrank(_alice);
        vm.expectRevert("Ownable: caller is not the owner");
        _nativeConverter.unpause();
        assertEq(_nativeConverter.paused(), true);
    }
}
