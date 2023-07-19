// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

// This contract will receive USDC from users on L1 and trigger BridgeMinter on the zkEVM via LxLy.
// This contract will hold all of the backing for USDC on zkEVM.
contract L1Escrow {
    // TODO: upgradeable

    IPolygonZkEVMBridge public immutable bridge;
    uint32 public immutable zkChainId;
    address public immutable zkContract;
    address public immutable l1Usdc; // TODO: replace with IUSDC

    constructor(
        IPolygonZkEVMBridge bridge_,
        uint32 zkChainId_,
        address zkContract_,
        address l1Usdc_
    ) {
        // TODO: TBI
        bridge = bridge_;
        zkChainId = zkChainId_;
        zkContract = zkContract_;
        l1Usdc = l1Usdc_;
    }

    function deposit(address zkReceiver, uint256 amount) external {
        // User calls deposit() on L1Escrow, L1_USDC transferred to L1Escrow
        // message sent to zkEVMBridge targeted to zkEVM’s BridgeMinter.

        // TODO: TBI

        require(zkReceiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // TODO: move USDC from the user to the escrow
        // l1Usdc.safeTransferFrom(msg.sender, address(this), amount);

        // tell our zk minter to mint usdc to the receiver
        bytes memory data = abi.encode(zkReceiver, amount);
        bridge.bridgeMessage(zkChainId, zkContract, true, data); // TODO: forceUpdateGlobalExitRoot TBD
    }

    function onMessageReceived(
        address originAddress,
        uint32 originChain,
        bytes memory data
    ) external payable {
        // Function triggered by the bridge once a message is received by the other network

        // TODO: TBI

        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(zkContract == originAddress, "NOT_ZK_CONTRACT");
        require(zkChainId == originChain, "NOT_ZK_CHAIN");

        // decode message data and call mint
        (address l1Addr, uint256 amount) = abi.decode(data, (address, uint256));
        _withdraw(l1Addr, amount);
    }

    function _withdraw(address l1Receiver, uint256 amount) internal {
        // Message claimed and sent to L1Escrow,
        // which transfers L1_USDC to the correct address.

        // TODO: TBI

        require(l1Receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // TODO: transfer USDC to receiver
        // l1Usdc.safeTransfer(l1Receiver, amount);
    }
}
