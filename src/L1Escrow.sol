// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IBridgeMessageReceiver.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {CommonAdminOwner} from "./CommonAdminOwner.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";
import {LibPermit} from "./helpers/LibPermit.sol";

// This contract will receive USDC from users on L1 and trigger BridgeMinter on the zkEVM via LxLy.
// This contract will hold all of the backing for USDC on zkEVM.
contract L1Escrow is IBridgeMessageReceiver, CommonAdminOwner {
    using SafeERC20Upgradeable for IUSDC;

    event Deposit(address indexed from, address indexed to, uint256 amount);

    IPolygonZkEVMBridge public bridge;
    uint32 public zkNetworkId;
    address public zkMinterBurner;
    IUSDC public l1USDC;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

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

    function bridgeToken(
        address destinationAddress,
        uint256 amount,
        bool forceUpdateGlobalExitRoot
    ) public whenNotPaused {
        // User calls deposit() on L1Escrow, L1_USDC transferred to L1Escrow
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

    function onMessageReceived(
        address originAddress,
        uint32 originNetwork,
        bytes memory data
    ) external payable whenNotPaused {
        // Function triggered by the bridge once a message is received by the other network

        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(zkMinterBurner == originAddress, "NOT_MINTER_BURNER");
        require(zkNetworkId == originNetwork, "NOT_ZK_CHAIN");

        // decode message data and call withdraw
        (address l1Receiver, uint256 amount) = abi.decode(
            data,
            (address, uint256)
        );

        // Message claimed and sent to L1Escrow,
        // which transfers L1_USDC to the correct address.

        // kinda redundant - these checks are being done by the caller
        require(l1Receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // send the locked L1_USDC to the receiver
        l1USDC.safeTransfer(l1Receiver, amount);
    }
}
