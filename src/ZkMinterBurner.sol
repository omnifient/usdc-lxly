// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IBridgeMessageReceiver.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {CommonAdminOwner} from "./CommonAdminOwner.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";
import {LibPermit} from "./helpers/LibPermit.sol";

// - Minter
// This contract will receive messages from the LXLY bridge on zkEVM,
// it will hold the minter role giving it the ability to mint USDC.e
// based on instructions from LXLY from Ethereum only.
// - Burner
// This contract will send messages to LXLY bridge on zkEVM,
// it will hold the burner role giving it the ability to burn USDC.e based on instructions from LXLY,
// triggering a release of assets on L1Escrow.
contract ZkMinterBurner is IBridgeMessageReceiver, CommonAdminOwner {
    using SafeERC20Upgradeable for IUSDC;

    event Withdraw(address indexed from, address indexed to, uint256 amount);

    IPolygonZkEVMBridge public bridge;
    uint32 public l1NetworkId;
    address public l1Escrow;
    IUSDC public zkUSDCe;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

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

    function bridgeToken(
        address destinationAddress,
        uint256 amount,
        bool forceUpdateGlobalExitRoot
    ) public whenNotPaused {
        // User calls withdraw() on BridgeBurner
        // which calls burn() on NativeUSDC burning the supply.
        // Message is sent to PolygonZkEVMBridge targeted to L1Escrow.

        require(destinationAddress != address(0), "INVALID_RECEIVER");
        // this is redundant - the usdc contract does the same validation
        // require(amount > 0, "INVALID_AMOUNT");

        // transfer the USDC.E from the user, and then burn it
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

        // Message claimed and sent to ZkMinterBurner,
        // which calls mint() on zkUSDCe
        // which mints new supply to the correct address.

        // this is redundant - the zkUSDCe contract does the same validations
        // require(zkReceiver != address(0), "INVALID_RECEIVER");
        // require(amount > 0, "INVALID_AMOUNT");

        // mint zkUSDCe to the receiver address
        zkUSDCe.mint(zkReceiver, amount);
    }
}
