// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This contract will send messages to LXLY bridge on zkEVM,
// it will hold the burner role giving it the ability to burn USDC.e based on instructions from LXLY,
// triggering a release of assets on L1Escrow.
contract BridgeBurner {
    // TODO: upgradeable

    constructor() {
        // TODO: TBI
        // LXLY bridge address
        // USDC.e address
    }

    function withdraw(address l1Receiver, uint256 amount) external {
        // TODO: TBI
        // User calls withdraw() on BridgeBurner
        // which calls burn() on NativeUSDC burning the supply.
        // Message is sent to zkEVMBridge targeted to L1Escrow.
        // TODO: call USDCe.burn
        // TODO: send msg to bridge w/ l1Receiver
    }
}
