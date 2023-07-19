// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";

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

    using SafeERC20 for IUSDC;

    IPolygonZkEVMBridge public immutable bridge;
    uint32 public immutable l1ChainId;
    address public immutable l1Contract;
    IUSDC public immutable zkUsdc;

    constructor(
        IPolygonZkEVMBridge bridge_,
        uint32 l1ChainId_,
        address l1Contract_,
        address zkUsdc_
    ) {
        bridge = bridge_;
        l1ChainId = l1ChainId_;
        l1Contract = l1Contract_;
        zkUsdc = IUSDC(zkUsdc_);
    }

    function onMessageReceived(
        address originAddress,
        uint32 originChain,
        bytes memory data
    ) external payable {
        // Function triggered by the bridge once a message is received by the other network

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

        // this is redundant - the usdc contract does the same validations
        // require(zkReceiver != address(0), "INVALID_RECEIVER");
        // require(amount > 0, "INVALID_AMOUNT");

        // mint USDC.E to target address
        zkUsdc.mint(zkReceiver, amount);
    }

    function withdraw(address l1Receiver, uint256 amount) external {
        // User calls withdraw() on BridgeBurner
        // which calls burn() on NativeUSDC burning the supply.
        // Message is sent to zkEVMBridge targeted to L1Escrow.

        require(l1Receiver != address(0), "INVALID_RECEIVER");
        // this is redundant - the usdc contract does the same validation
        // require(amount > 0, "INVALID_AMOUNT");

        // transfer the USDC.E from the user, and then burn it
        zkUsdc.safeTransferFrom(msg.sender, address(this), amount);
        zkUsdc.burn(amount);

        // message L1Escrow to unlock the L1_USDC and transfer it to l1Receiver
        bytes memory data = abi.encode(l1Receiver, amount);
        bridge.bridgeMessage(l1ChainId, l1Contract, true, data); // TODO: forceUpdateGlobalExitRoot TBD
    }
}
