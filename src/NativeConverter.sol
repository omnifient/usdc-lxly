// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";
import {Ownable} from "@oz/access/Ownable.sol";
import {Pausable} from "@oz/security/Pausable.sol";
import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";

// This contract will receive BridgeWrappedUSDC on zkEVM and issue USDC.e on zkEVM.
// This contract will hold the minter role giving it the ability to mint USDC.e based on inflows of BridgeWrappedUSDC.
// This contract will also have a permissionless publicly callable function called “migrate” which when called will
// withdraw all BridgedWrappedUSDC to L1 via the LXLY bridge. The beneficiary address will be the L1Escrow,
// thus migrating the supply and settling the balance.
contract NativeConverter is Ownable, Pausable {
    // TODO: upgradeable

    using SafeERC20 for IUSDC;

    IPolygonZkEVMBridge public immutable bridge;
    uint32 public immutable l1ChainId;
    address public immutable l1Escrow;
    IUSDC public immutable zkUSDCe;
    IUSDC public immutable zkBWUSDC;

    constructor(
        IPolygonZkEVMBridge bridge_,
        uint32 l1ChainId_,
        address l1Escrow_,
        address zkUSDCe_,
        address zkBWUSDC_
    ) {
        bridge = bridge_;
        l1ChainId = l1ChainId_;
        l1Escrow = l1Escrow_;
        zkUSDCe = IUSDC(zkUSDCe_);
        zkBWUSDC = IUSDC(zkBWUSDC_);
    }

    function convert(uint256 amount, address receiver) external whenNotPaused {
        // User calls convert() on NativeConverter,
        // BridgeWrappedUSDC is transferred to NativeConverter
        // NativeConverter calls mint() on NativeUSDC which mints
        // new supply to the correct address.

        require(receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // transfer the wrapped usdc to the converter, and mint back native usdc
        zkBWUSDC.safeTransferFrom(msg.sender, address(this), amount);
        zkUSDCe.mint(receiver, amount);
    }

    function migrate() external whenNotPaused {
        // Anyone can call migrate() on NativeConverter to
        // have all BridgeWrappedUSDC withdrawn via the zkEVMBridge
        // moving the L1_USDC held in the zkEVMBridge to L1Escrow

        // TODO: TBD and TBI
        uint256 amount = zkBWUSDC.balanceOf(address(this));
        // bytes memory data = abi.encode(l1Escrow, amount);
        // bridge.bridgeMessage(l1ChainId, l1Escrow, true, data); // TODO: forceUpdateGlobalExitRoot TBD
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
}
