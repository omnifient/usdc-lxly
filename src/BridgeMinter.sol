// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// This contract will receive messages from the LXLY bridge on zkEVM,
// it will hold the minter role giving it the ability to mint USDC.e
// based on instructions from LXLY from Ethereum only.
contract BridgeMinter {
    // TODO: upgradeable

    constructor() {
        // TODO: TBI
        // LXLY bridge address
        // USDC.e address
    }

    function _mint(address zkReceiver, uint256 amount) internal {
        // TODO: TBI
        // Message claimed and sent to BridgeMinter,
        // which calls mint() on NativeUSDC
        // which mints new supply to the correct address.
        // TODO: mint USDC.e to target address
    }
}
