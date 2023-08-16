// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Base} from "../Base.sol";

contract MigrateFlows is Base {
    function _emitMigrateBridgeEvent(uint256 counter) internal {
        uint256 amount = _erc20L2Wusdc.balanceOf(address(_nativeConverter));
        address receiver = address(_l1Escrow);

        emit BridgeEvent(
            0, // _LEAF_TYPE_ASSET
            _l1NetworkId, // originNetwork is the origin network of the underlying asset
            _l1Usdc, // originTokenAddress
            _l1NetworkId, // Migrate always targets L2
            receiver, // destinationAddress
            amount, // amount
            "", // metadata is empty when bridging wrapped assets
            uint32(18003 + counter) // ATTN: deposit count in mainnet block 17785773
        );
    }

    bytes private _emptyBytes;

    /// @notice Alice converts 1000 L2_WUSDC to L2_USDC, then calls migrate,
    /// causing NativeConverter to bridge 1000 L2_WUSDC, resulting in 1000
    /// L1_USDC being sent to L1Escrow.
    function testMigrateWithWUSDC() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // Alice converts some wusdc to usdc
        // this causes L2_WUSDC to be sent to NativeConverter
        uint256 amount = _toUSDC(1000);
        uint256 balance1 = _erc20L2Wusdc.balanceOf(_alice);
        uint256 wusdcSupply1 = _erc20L2Wusdc.totalSupply();
        _erc20L2Wusdc.approve(address(_nativeConverter), amount);
        _nativeConverter.convert(_alice, amount, _emptyBytes);

        // check that NativeConverter has the L2_BWUSDC
        assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), amount);

        // prepare to call NativeConverter.migrate, which will bridge the assets
        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitMigrateBridgeEvent(0);

        // check that our migrate event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Migrate(amount);

        // migrate all of the L2_BWUSDC to L1
        _nativeConverter.migrate();

        // manually trigger the "bridging"
        _claimBridgeAsset(_l2NetworkId, _l1NetworkId);

        // check alice no longer has the L2_WUSDC
        vm.selectFork(_l2Fork);
        uint256 balance2 = _erc20L2Wusdc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount);

        // check that the supply of L2_WUSDC decreased
        uint256 wusdcSupply2 = _erc20L2Wusdc.totalSupply();
        assertEq(wusdcSupply1 - wusdcSupply2, amount);

        // check nativeconverter no longer has L2_WUSDC
        assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), 0);

        // check l1escrow got the L1_USDC
        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Usdc.balanceOf(address(_l1Escrow)), amount);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// @notice Alice converts 1000 L2_WUSDC to L2_USDC, then calls migrate,
    /// Alice converts 500 L2_WUSDC to L2_USDC, then calls migrate again,
    /// and the migrations execute correctly.
    function testMultipleMigratesWithWUSDC() public {
        vm.selectFork(_l2Fork);
        vm.startPrank(_alice);

        // Alice converts some wusdc to usdc
        // this causes L2_WUSDC to be sent to NativeConverter
        uint256 amount1 = _toUSDC(1000);
        uint256 balance1 = _erc20L2Wusdc.balanceOf(_alice);
        uint256 wusdcSupply1 = _erc20L2Wusdc.totalSupply();
        _erc20L2Wusdc.approve(address(_nativeConverter), amount1);
        _nativeConverter.convert(_alice, amount1, _emptyBytes);

        // check that NativeConverter has the L2_BWUSDC
        assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), amount1);

        // prepare to call NativeConverter.migrate, which will bridge the assets
        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitMigrateBridgeEvent(0);

        // check that our migrate event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Migrate(amount1);

        // migrate all of the L2_BWUSDC to L1
        _nativeConverter.migrate();

        // manually trigger the "bridging"
        _claimBridgeAsset(_l2NetworkId, _l1NetworkId);

        // check alice no longer has the L2_WUSDC
        vm.selectFork(_l2Fork);
        uint256 balance2 = _erc20L2Wusdc.balanceOf(_alice);
        assertEq(balance1 - balance2, amount1);

        // check nativeconverter no longer has L2_WUSDC
        assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), 0);

        // check l1escrow got the L1_USDC
        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Usdc.balanceOf(address(_l1Escrow)), amount1);

        _assertUsdcSupplyAndBalancesMatch();

        // Alice converts some more wusdc to usdc
        uint256 amount2 = _toUSDC(500);
        _erc20L2Wusdc.approve(address(_nativeConverter), amount2);
        _nativeConverter.convert(_alice, amount2, _emptyBytes);

        // check that NativeConverter has the L2_BWUSDC
        assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), amount2);

        // prepare to call NativeConverter.migrate, which will bridge the assets
        // check that a bridge event is emitted
        vm.expectEmit(_bridge);
        _emitMigrateBridgeEvent(1);

        // check that our migrate event is emitted
        vm.expectEmit(address(_nativeConverter));
        emit Migrate(amount2);

        // migrate all of the L2_BWUSDC to L1
        _nativeConverter.migrate();

        // manually trigger the "bridging"
        _claimBridgeAsset(_l2NetworkId, _l1NetworkId);

        // check alice no longer has the L2_WUSDC
        vm.selectFork(_l2Fork);
        uint256 balance3 = _erc20L2Wusdc.balanceOf(_alice);
        assertEq(balance2 - balance3, amount2);

        // check nativeconverter no longer has L2_WUSDC
        assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), 0);

        // check that the supply of L2_WUSDC decreased
        uint256 wusdcSupply2 = _erc20L2Wusdc.totalSupply();
        assertEq(wusdcSupply1 - wusdcSupply2, amount1 + amount2);

        // check l1escrow got the L1_USDC
        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Usdc.balanceOf(address(_l1Escrow)), amount1 + amount2);

        _assertUsdcSupplyAndBalancesMatch();
    }

    /// No L2_WUSDC is present in the bridge, and migrate is called.
    function testMigrateWithoutWUSDC() public {
        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Usdc.balanceOf(address(_l1Escrow)), 0);

        vm.selectFork(_l2Fork);
        assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), 0);

        // nothing happens
        _nativeConverter.migrate();

        assertEq(_erc20L2Wusdc.balanceOf(address(_nativeConverter)), 0);

        vm.selectFork(_l1Fork);
        assertEq(_erc20L1Usdc.balanceOf(address(_l1Escrow)), 0);

        _assertUsdcSupplyAndBalancesMatch();
    }
}
