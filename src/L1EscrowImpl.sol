// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";
import "@oz/access/Ownable.sol";
import "@oz/proxy/utils/UUPSUpgradeable.sol";
import "@oz/security/Pausable.sol";
import "@oz/token/ERC20/utils/SafeERC20.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";

// This contract will receive USDC from users on L1 and trigger BridgeMinter on the zkEVM via LxLy.
// This contract will hold all of the backing for USDC on zkEVM.
contract L1EscrowImpl is Ownable, Pausable, UUPSUpgradeable {
    using SafeERC20 for IUSDC;

    // TODO: pack variables
    IPolygonZkEVMBridge public bridge;
    uint32 public zkChainId;
    address public zkContract;
    IUSDC public l1Usdc;

    function initialize(
        address bridge_,
        uint32 zkChainId_,
        address zkContract_,
        address l1Usdc_
    ) external onlyOwner {
        // TODO: use OZ's Initializable or add if(!initialized)
        bridge = IPolygonZkEVMBridge(bridge_);
        zkChainId = zkChainId_;
        zkContract = zkContract_;
        l1Usdc = IUSDC(l1Usdc_);
    }

    function deposit(
        address zkReceiver,
        uint256 amount
    ) external whenNotPaused {
        // User calls deposit() on L1Escrow, L1_USDC transferred to L1Escrow
        // message sent to zkEVMBridge targeted to zkEVM’s BridgeMinter.

        require(zkReceiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // move usdc from the user to the escrow
        l1Usdc.safeTransferFrom(msg.sender, address(this), amount);

        // tell our zk minter to mint usdc to the receiver
        bytes memory data = abi.encode(zkReceiver, amount);
        bridge.bridgeMessage(zkChainId, zkContract, true, data); // TODO: forceUpdateGlobalExitRoot TBD
    }

    function onMessageReceived(
        address originAddress,
        uint32 originChain,
        bytes memory data
    ) external payable whenNotPaused {
        // Function triggered by the bridge once a message is received by the other network

        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(zkContract == originAddress, "NOT_ZK_CONTRACT");
        require(zkChainId == originChain, "NOT_ZK_CHAIN");

        // decode message data and call withdraw
        (address l1Addr, uint256 amount) = abi.decode(data, (address, uint256));
        _withdraw(l1Addr, amount);
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _withdraw(address l1Receiver, uint256 amount) internal {
        // Message claimed and sent to L1Escrow,
        // which transfers L1_USDC to the correct address.

        // kinda redundant - these checks are being done by the caller
        require(l1Receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // send the locked L1_USDC to the receiver
        l1Usdc.safeTransfer(l1Receiver, amount);
    }
}
