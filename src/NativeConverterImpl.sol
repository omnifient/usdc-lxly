// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";
import "@oz/access/Ownable.sol";
import "@oz/proxy/utils/UUPSUpgradeable.sol";
import "@oz/security/Pausable.sol";
import "@oz/token/ERC20/utils/SafeERC20.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";

// This contract will receive BridgeWrappedUSDC on zkEVM and issue USDC.e on zkEVM.
// This contract will hold the minter role giving it the ability to mint USDC.e based on inflows of BridgeWrappedUSDC.
// This contract will also have a permissionless publicly callable function called “migrate” which when called will
// withdraw all BridgedWrappedUSDC to L1 via the LXLY bridge. The beneficiary address will be the L1Escrow,
// thus migrating the supply and settling the balance.
contract NativeConverterImpl is Ownable, Pausable, UUPSUpgradeable {
    using SafeERC20 for IUSDC;

    event Convert(address indexed from, address indexed to, uint256 amount);
    event Migrate(uint256 amount);

    // TODO: pack variables
    IPolygonZkEVMBridge public bridge;
    uint32 public l1ChainId;
    address public l1Escrow;
    IUSDC public zkUSDCe;
    IUSDC public zkBWUSDC;

    function initialize(
        address bridge_,
        uint32 l1ChainId_,
        address l1Escrow_,
        address zkUSDCe_,
        address zkBWUSDC_
    ) external onlyProxy {
        require(msg.sender == _getAdmin(), "NOT_ADMIN");

        // TODO: use OZ's Initializable or add if(!initialized)
        _transferOwnership(msg.sender); // TODO: arg from initialize

        bridge = IPolygonZkEVMBridge(bridge_);
        l1ChainId = l1ChainId_;
        l1Escrow = l1Escrow_;
        zkUSDCe = IUSDC(zkUSDCe_);
        zkBWUSDC = IUSDC(zkBWUSDC_);
    }

    function convert(address receiver, uint256 amount) external whenNotPaused {
        // User calls convert() on NativeConverter,
        // BridgeWrappedUSDC is transferred to NativeConverter
        // NativeConverter calls mint() on NativeUSDC which mints
        // new supply to the correct address.

        require(receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // transfer the wrapped usdc to the converter, and mint back native usdc
        zkBWUSDC.safeTransferFrom(msg.sender, address(this), amount);
        zkUSDCe.mint(receiver, amount);

        emit Convert(msg.sender, receiver, amount);
    }

    function migrate() external whenNotPaused {
        // Anyone can call migrate() on NativeConverter to
        // have all BridgeWrappedUSDC withdrawn via the zkEVMBridge
        // moving the L1_USDC held in the zkEVMBridge to L1Escrow

        // TODO: TBD and TBI
        uint256 amount = zkBWUSDC.balanceOf(address(this));

        if (amount > 0) {
            // bytes memory data = abi.encode(l1Escrow, amount);
            // bridge.bridgeMessage(l1ChainId, l1Escrow, true, data); // TODO: forceUpdateGlobalExitRoot TBD

            emit Migrate(amount);
        }
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
}
