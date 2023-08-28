// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IBridgeMessageReceiver.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {CommonAdminOwner} from "./CommonAdminOwner.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";
import {LibPermit} from "./helpers/LibPermit.sol";

/// @title ZkMinterBurner
/// @notice This upgradeable L2 contract facilitates 2 actions:
/// 1. Minting USDC-E on the zkEVM backed by L1 USDC held in the L1Escrow
/// 2. Burning USDC-E on the zkEVM and sending a bridge message to unlock the
/// corresponding funds held in the L1Escrow (the reverse of (1) above).
contract ZkMinterBurner is IBridgeMessageReceiver, CommonAdminOwner {
    using SafeERC20Upgradeable for IUSDC;

    event Withdraw(address indexed from, address indexed to, uint256 amount);

    /// @notice The singleton bridge contract on both L1 and L2 (zkEVM) that faciliates
    /// @notice bridging messages between L1 and L2. It also stores all of the L1 USDC
    /// @notice backing the L2 BridgeWrappedUSDC
    IPolygonZkEVMBridge public bridge;

    /// @notice The ID used internally by the bridge to identify L1 messages. Initially
    /// @notice set to be `0`
    uint32 public l1NetworkId;

    /// @notice The address of the L1Escrow
    address public l1Escrow;

    /// @notice The address of the L2 USDC-e ERC20 token
    IUSDC public zkUSDCe;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

    /// @notice Setup the state variables of the upgradeable ZkMinterBurner contract
    /// @notice the owner is the contract that is able to pause and unpause function calls
    function initialize(
        address owner_,
        address admin_,
        address bridge_,
        uint32 l1NetworkId_,
        address l1EscrowProxy_,
        address zkUSDCe_
    ) external onlyProxy onlyAdmin initializer {
        require(bridge_ != address(0), "INVALID_BRIDGE");
        require(l1EscrowProxy_ != address(0), "INVALID_L1ESCROW");
        require(zkUSDCe_ != address(0), "INVALID_USDC_E");
        require(owner_ != address(0), "INVALID_OWNER");
        require(admin_ != address(0), "INVALID_ADMIN");

        __CommonAdminOwner_init();

        _transferOwnership(owner_);
        _changeAdmin(admin_);

        bridge = IPolygonZkEVMBridge(bridge_);
        l1NetworkId = l1NetworkId_;
        l1Escrow = l1EscrowProxy_;
        zkUSDCe = IUSDC(zkUSDCe_);
    }

    /// @notice Bridges L2 USDC-e to L1 USDC
    /// @dev The ZkMinterBurner transfers L2 USDC-e from the caller to itself and
    /// @dev burns it, thencalls `bridge.bridgeMessage, which ultimately results in a message
    /// @dev received on the L1Escrow which unlocks the corresponding L1 USDC to the
    /// @dev destination address
    /// @dev Can be paused
    /// @param destinationAddress address that will receive L1 USDC on the L1
    /// @param amount amount of L2 USDC-e to bridge
    /// @param forceUpdateGlobalExitRoot whether or not to force the bridge to update
    function bridgeToken(
        address destinationAddress,
        uint256 amount,
        bool forceUpdateGlobalExitRoot
    ) public whenNotPaused {
        require(destinationAddress != address(0), "INVALID_RECEIVER");
        // this is redundant - the usdc contract does the same validation
        // require(amount > 0, "INVALID_AMOUNT");

        // transfer the USDC-E from the user, and then burn it
        zkUSDCe.safeTransferFrom(msg.sender, address(this), amount);
        zkUSDCe.burn(amount);

        // message L1Escrow to unlock the L1_USDC and transfer it to destinationAddress
        bytes memory data = abi.encode(destinationAddress, amount);
        bridge.bridgeMessage(
            l1NetworkId,
            l1Escrow,
            forceUpdateGlobalExitRoot,
            data
        );

        emit Withdraw(msg.sender, destinationAddress, amount);
    }

    /// @notice Similar to {ZkMinterBurnerImpl-bridgeToken}, but saves an ERC20.approve call
    /// @notice by using the EIP-2612 permit function
    function bridgeToken(
        address destinationAddress,
        uint256 amount,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) external whenNotPaused {
        if (permitData.length > 0)
            LibPermit.permit(address(zkUSDCe), amount, permitData);

        bridgeToken(destinationAddress, amount, forceUpdateGlobalExitRoot);
    }

    /// @dev This function is triggered by the bridge to faciliate the USDC-e minting process.
    /// @dev This function is called by the bridge when a message is sent by the L1Escrow
    /// @dev communicating that it has received L1 USDC and wants the ZkMinterBurner to
    /// @dev mint USDC-e.
    /// @dev This function can only be called by the bridge contract
    /// @dev Can be paused
    function onMessageReceived(
        address originAddress,
        uint32 originNetwork,
        bytes memory data
    ) external payable whenNotPaused {
        // Function triggered by the bridge once a message is received from the L1Escrow

        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(l1Escrow == originAddress, "NOT_L1_ESCROW_CONTRACT");
        require(l1NetworkId == originNetwork, "NOT_L1_CHAIN");

        // decode message data and call mint
        (address zkReceiver, uint256 amount) = abi.decode(
            data,
            (address, uint256)
        );

        // this is redundant - the zkUSDCe contract does the same validations
        // require(zkReceiver != address(0), "INVALID_RECEIVER");
        // require(amount > 0, "INVALID_AMOUNT");

        // mint zkUSDCe to the receiver address
        zkUSDCe.mint(zkReceiver, amount);
    }
}
