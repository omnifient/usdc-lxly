// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IBridgeMessageReceiver.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {CommonAdminOwner} from "./CommonAdminOwner.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";
import {LibPermit} from "./helpers/LibPermit.sol";

/// @title L1Escrow
/// @notice This upgradeable contract receives USDC from users on L1 and uses the PolygonZkEVMBridge
/// to send a message to the ZkMinterBurner contract on the L2 (zkEVM) which
/// then mints USDC-e for users
/// @notice This contract holds all of the L1 USDC that backs the USDC-e on the zkEVM
/// @notice This contract is upgradeable using UUPS, and can have its important functions
/// paused and unpaused
contract L1Escrow is IBridgeMessageReceiver, CommonAdminOwner {
    using SafeERC20Upgradeable for IUSDC;

    event Deposit(address indexed from, address indexed to, uint256 amount);

    /// @notice The singleton bridge contract on both L1 and L2 (zkEVM) that faciliates
    /// bridging messages between L1 and L2. It also stores all of the L1 USDC
    /// backing the L2 BridgeWrappedUSDC
    IPolygonZkEVMBridge public bridge;

    /// @notice The ID used internally by the bridge to identify zkEVM messages. Initially
    /// set to be `1`
    uint32 public zkNetworkId;

    /// @notice Address of the L2 ZkMinterBurner, which receives messages from the L1Escrow
    address public zkMinterBurner;

    /// @notice Address of the L1 USDC token
    IUSDC public l1USDC;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

    /// @notice Setup the state variables of the upgradeable L1Escrow contract
    /// @notice The owner is the address that is able to pause and unpause function calls
    /// @param owner_ the address that will be able to pause and unpause the contract,
    /// as well as transfer the ownership of the contract
    /// @param bridge_ the address of the PolygonZkEVMBridge deployed on the zkEVM
    /// @param zkNetworkId_ the ID used internally by the bridge to identify zkEVM messages
    /// @param zkMinterBurnerProxy_ the address of the ZkMinterBurnerProxy deployed on the L2
    /// @param l1Usdc_ the address of the L1 USDC deployed on the L1
    function initialize(
        address owner_,
        address admin_,
        address bridge_,
        uint32 zkNetworkId_,
        address zkMinterBurnerProxy_,
        address l1Usdc_
    ) external onlyProxy onlyAdmin initializer {
        require(bridge_ != address(0), "INVALID_BRIDGE");
        require(zkMinterBurnerProxy_ != address(0), "INVALID_MB");
        require(l1Usdc_ != address(0), "INVALID_L1_USDC");
        require(owner_ != address(0), "INVALID_OWNER");
        require(admin_ != address(0), "INVALID_ADMIN");

        __CommonAdminOwner_init();

        _transferOwnership(owner_);
        _changeAdmin(admin_);

        bridge = IPolygonZkEVMBridge(bridge_);
        zkNetworkId = zkNetworkId_;
        zkMinterBurner = zkMinterBurnerProxy_;
        l1USDC = IUSDC(l1Usdc_);
    }

    /// @notice Bridges L1 USDC to L2 USDC-e
    /// @dev The L1Escrow transfers L1 USDC from the caller to itself and
    /// calls `bridge.bridgeMessage, which ultimately results in a message
    /// received on the L2 ZkMinterBurner which mints USDC-e for the destination
    /// address
    /// @dev Can be paused
    /// @param destinationAddress address that will receive USDC-e on the L2
    /// @param amount amount of L1 USDC to bridge
    /// @param forceUpdateGlobalExitRoot whether or not to force the bridge to update.
    function bridgeToken(
        address destinationAddress,
        uint256 amount,
        bool forceUpdateGlobalExitRoot
    ) public whenNotPaused {
        // User calls `bridgeToken` on L1Escrow, L1_USDC is transferred to L1Escrow
        // message sent to PolygonZkEvmBridge targeted to L2's zkMinterBurner.

        require(destinationAddress != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // move L1-USDC from the user to the escrow
        l1USDC.safeTransferFrom(msg.sender, address(this), amount);
        // tell our zkMinterBurner to mint zkUSDCe to the receiver
        bytes memory data = abi.encode(destinationAddress, amount);
        bridge.bridgeMessage(
            zkNetworkId,
            zkMinterBurner,
            forceUpdateGlobalExitRoot,
            data
        );

        emit Deposit(msg.sender, destinationAddress, amount);
    }

    /// @notice Similar to other `bridgeToken` function, but saves an ERC20.approve call
    /// by using the EIP-2612 permit function
    function bridgeToken(
        address destinationAddress,
        uint256 amount,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) external whenNotPaused {
        if (permitData.length > 0)
            LibPermit.permit(address(l1USDC), amount, permitData);

        bridgeToken(destinationAddress, amount, forceUpdateGlobalExitRoot);
    }

    /// @dev This function is triggered by the bridge to faciliate the L1 USDC withdrawal process.
    /// This function is called by the bridge when a message is sent by the L2
    /// ZkMinterBurner communicating that it has burned USDC-e and wants to withdraw the L1 USDC
    /// that backs it.
    /// @dev This function can only be called by the bridge contract
    /// @dev Can be paused
    /// @param originAddress address that initiated the message on the L2
    /// @param originNetwork network that initiated the message on the L2
    /// @param data data that was sent with the message on the L2, includes the
    /// `l1Receiver` and `amount` of L1 USDC to send to the `l1Receiver`
    function onMessageReceived(
        address originAddress,
        uint32 originNetwork,
        bytes memory data
    ) external payable whenNotPaused {
        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(zkMinterBurner == originAddress, "NOT_MINTER_BURNER");
        require(zkNetworkId == originNetwork, "NOT_ZK_CHAIN");

        // decode message data and call transfer
        (address l1Receiver, uint256 amount) = abi.decode(
            data,
            (address, uint256)
        );

        // kinda redundant - these checks are being done by the caller
        require(l1Receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // send the locked L1_USDC to the receiver
        l1USDC.safeTransfer(l1Receiver, amount);
    }
}
