// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

// - Minter
// This contract will receive messages from the LXLY bridge on zkEVM,
// it will hold the minter role giving it the ability to mint USDC.e
// based on instructions from LXLY from Ethereum only.
// - Burner
// This contract will send messages to LXLY bridge on zkEVM,
// it will hold the burner role giving it the ability to burn USDC.e based on instructions from LXLY,
// triggering a release of assets on L1Escrow.
contract ZkMinterBurner {
    // TODO: upgradeable

    IPolygonZkEVMBridge public immutable bridge;
    uint32 public immutable l1ChainId;
    address public immutable l1Contract;
    address public immutable zkUsdc; // TODO: replace with IUSDC

    constructor(
        IPolygonZkEVMBridge bridge_,
        uint32 l1ChainId_,
        address l1Contract_,
        address zkUsdc_
    ) {
        // TODO: TBI
        bridge = bridge_;
        l1ChainId = l1ChainId_;
        l1Contract = l1Contract_;
        zkUsdc = zkUsdc_;
    }

    function onMessageReceived(
        address originAddress,
        uint32 originChain,
        bytes memory data
    ) external payable {
        // Function triggered by the bridge once a message is received by the other network

        // TODO: TBI

        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(l1Contract == originAddress, "NOT_L1_CONTRACT");
        require(l1ChainId == originChain, "NOT_L1_CHAIN");

        // decode message data and call mint
        (address zkAddr, uint256 amount) = abi.decode(data, (address, uint256));
        _mint(zkAddr, amount);
    }

    function _mint(address zkReceiver, uint256 amount) internal {
        // Message claimed and sent to BridgeMinter,
        // which calls mint() on NativeUSDC
        // which mints new supply to the correct address.

        // TODO: TBI

        require(zkReceiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // TODO: mint USDC.e to target address
        // zkUsdc.mint(zkReceiver, amount)
    }

    function withdraw(address l1Receiver, uint256 amount) external {
        // User calls withdraw() on BridgeBurner
        // which calls burn() on NativeUSDC burning the supply.
        // Message is sent to zkEVMBridge targeted to L1Escrow.

        // TODO: TBI

        require(l1Receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // TODO: call USDCe.burn
        // zkUsdc.safeTransferFrom(msg.sender, address(this), amount);
        // zkUsdc.burn(amount)

        // TODO: send msg to bridge w/ l1Receiver
        // Encode message data
        bytes memory data = abi.encode(l1Receiver, amount);
        // Send message data through the bridge
        bridge.bridgeMessage(l1ChainId, l1Contract, true, data); // TODO: forceUpdateGlobalExitRoot TBD
    }
}
