// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This contract will receive BridgeWrappedUSDC on zkEVM and issue USDC.e on zkEVM.
// This contract will hold the minter role giving it the ability to mint USDC.e based on inflows of BridgeWrappedUSDC.
// This contract will also have a permissionless publicly callable function called “migrate” which when called will
// withdraw all BridgedWrappedUSDC to L1 via the LXLY bridge. The beneficiary address will be the L1Escrow,
// thus migrating the supply and settling the balance.
contract NativeConverter {
    // TODO: upgradeable
    // TODO: pausable

    constructor() {
        // TODO: TBI
        // wUSDC address
        // USDCe address
        // L1Escrow address?
    }

    function convert(address receiver) external {
        // TODO: TBI
        // User calls convert() on NativeConverter,
        // BridgeWrappedUSDC is transferred to NativeConverter
        // NativeConverter calls mint() on NativeUSDC which mints
        // new supply to the correct address.
    }

    function migrate() external {
        // TODO: TBI
        // Anyone can call migrate() on NativeConverter to
        // have all BridgeWrappedUSDC withdrawn via the zkEVMBridge
        // moving the L1_USDC held in the zkEVMBridge to L1Escrow
    }
}
