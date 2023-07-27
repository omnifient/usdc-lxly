// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@oz/access/Ownable.sol";
import "@oz/proxy/utils/UUPSUpgradeable.sol";
import "@oz/security/Pausable.sol";
import "@oz/token/ERC20/utils/SafeERC20.sol";
import "@zkevm/interfaces/IBridgeMessageReceiver.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";

// - Minter
// This contract will receive messages from the LXLY bridge on zkEVM,
// it will hold the minter role giving it the ability to mint USDC.e
// based on instructions from LXLY from Ethereum only.
// - Burner
// This contract will send messages to LXLY bridge on zkEVM,
// it will hold the burner role giving it the ability to burn USDC.e based on instructions from LXLY,
// triggering a release of assets on L1Escrow.
contract ZkMinterBurnerImpl is
    IBridgeMessageReceiver,
    Ownable,
    Pausable,
    UUPSUpgradeable
{
    using SafeERC20 for IUSDC;

    event Withdraw(address indexed from, address indexed to, uint256 amount);

    // TODO: pack variables
    IPolygonZkEVMBridge public bridge;
    uint32 public l1ChainId;
    address public l1Contract;
    IUSDC public zkUsdc;

    function initialize(
        address bridge_,
        uint32 l1ChainId_,
        address l1Contract_,
        address zkUsdc_
    ) external onlyOwner {
        // TODO: use OZ's Initializable or add if(!initialized)
        bridge = IPolygonZkEVMBridge(bridge_);
        l1ChainId = l1ChainId_;
        l1Contract = l1Contract_;
        zkUsdc = IUSDC(zkUsdc_);
    }

    function onMessageReceived(
        address originAddress,
        uint32 originChain,
        bytes memory data
    ) external payable whenNotPaused {
        // Function triggered by the bridge once a message is received by the other network

        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(l1Contract == originAddress, "NOT_L1_CONTRACT");
        require(l1ChainId == originChain, "NOT_L1_CHAIN");

        // decode message data and call mint
        (address zkAddr, uint256 amount) = abi.decode(data, (address, uint256));
        _mint(zkAddr, amount);
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

    function withdraw(
        address l1Receiver,
        uint256 amount
    ) external whenNotPaused {
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

        emit Withdraw(msg.sender, l1Receiver, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

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
}
