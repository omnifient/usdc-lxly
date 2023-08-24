// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IBridgeMessageReceiver.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

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
contract ZkMinterBurnerImpl is
    IBridgeMessageReceiver,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IUSDC;

    event Withdraw(address indexed from, address indexed to, uint256 amount);

    IPolygonZkEVMBridge public bridge;
    uint32 public l1NetworkId;
    address public l1Contract;
    IUSDC public zkUsdc;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

    function initialize(
        address owner_,
        address bridge_,
        uint32 l1NetworkId_,
        address l1Contract_,
        address zkUsdc_
    ) external onlyProxy initializer {
        require(msg.sender == _getAdmin(), "NOT_ADMIN");
        require(bridge_ != address(0), "INVALID_ADDRESS");
        require(l1Contract_ != address(0), "INVALID_ADDRESS");
        require(zkUsdc_ != address(0), "INVALID_ADDRESS");
        require(owner_ != address(0), "INVALID_ADDRESS");

        __Ownable_init(); // ATTN: we override this later
        __Pausable_init(); // NOOP
        __UUPSUpgradeable_init(); // NOOP

        _transferOwnership(owner_);

        bridge = IPolygonZkEVMBridge(bridge_);
        l1NetworkId = l1NetworkId_;
        l1Contract = l1Contract_;
        zkUsdc = IUSDC(zkUsdc_);
    }

    function bridgeToken(
        address destinationAddress,
        uint256 amount,
        bool forceUpdateGlobalExitRoot
    ) public whenNotPaused {
        // User calls withdraw() on BridgeBurner
        // which calls burn() on NativeUSDC burning the supply.
        // Message is sent to zkEVMBridge targeted to L1Escrow.

        require(destinationAddress != address(0), "INVALID_RECEIVER");
        // this is redundant - the usdc contract does the same validation
        // require(amount > 0, "INVALID_AMOUNT");

        // transfer the USDC.E from the user, and then burn it
        zkUsdc.safeTransferFrom(msg.sender, address(this), amount);
        zkUsdc.burn(amount);

        // message L1Escrow to unlock the L1_USDC and transfer it to destinationAddress
        bytes memory data = abi.encode(destinationAddress, amount);
        bridge.bridgeMessage(
            l1NetworkId,
            l1Contract,
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
            LibPermit.permit(address(zkUsdc), amount, permitData);

        bridgeToken(destinationAddress, amount, forceUpdateGlobalExitRoot);
    }

    function onMessageReceived(
        address originAddress,
        uint32 originNetwork,
        bytes memory data
    ) external payable whenNotPaused {
        // Function triggered by the bridge once a message is received by the other network

        require(msg.sender == address(bridge), "NOT_BRIDGE");
        require(l1Contract == originAddress, "NOT_L1_CONTRACT");
        require(l1NetworkId == originNetwork, "NOT_L1_CHAIN");

        // decode message data and call mint
        (address zkAddr, uint256 amount) = abi.decode(data, (address, uint256));

        // Message claimed and sent to BridgeMinter,
        // which calls mint() on NativeUSDC
        // which mints new supply to the correct address.

        // this is redundant - the usdc contract does the same validations
        // require(zkReceiver != address(0), "INVALID_RECEIVER");
        // require(amount > 0, "INVALID_AMOUNT");

        // mint USDC.E to target address
        zkUsdc.mint(zkAddr, amount);
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

    function _authorizeUpgrade(address newImplementation) internal override {
        require(msg.sender == _getAdmin(), "NOT_ADMIN");
    }
}
