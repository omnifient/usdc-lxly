// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This contract will receive USDC from users on L1 and trigger BridgeMinter on the zkEVM via LxLy.
// This contract will hold all of the backing for USDC on zkEVM.
contract L1Escrow {
    // TODO: upgradeable

    constructor() {
        // TODO: TBI
        // USDC address
        // LXLY bridge address
        // BridgeMinter address?
    }

    function deposit(address zkReceiver, uint256 amount) external {
        // TODO: TBI
        // User calls deposit() on L1Escrow, L1_USDC transferred to L1Escrow
        // message sent to zkEVMBridge targeted to zkEVM’s BridgeMinter.
    }

    function _withdraw(address l1Receiver, uint256 amount) internal {
        // TODO: TBI
        // Message claimed and sent to L1Escrow,
        // which transfers L1_USDC to the correct address.
        // TODO: only called by the bridge
        // TODO: transfer USDC to receiver
    }
}
