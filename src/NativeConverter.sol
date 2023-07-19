// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

// This contract will receive BridgeWrappedUSDC on zkEVM and issue USDC.e on zkEVM.
// This contract will hold the minter role giving it the ability to mint USDC.e based on inflows of BridgeWrappedUSDC.
// This contract will also have a permissionless publicly callable function called “migrate” which when called will
// withdraw all BridgedWrappedUSDC to L1 via the LXLY bridge. The beneficiary address will be the L1Escrow,
// thus migrating the supply and settling the balance.
contract NativeConverter {
    // TODO: upgradeable
    // TODO: pausable

    IPolygonZkEVMBridge public immutable bridge;
    uint32 public immutable l1ChainId;
    address public immutable l1Escrow;
    address public immutable zkUSDCe; // TODO: replace with IUSDC
    address public immutable zkBWUSDC; // TODO: ERC20

    constructor(
        IPolygonZkEVMBridge bridge_,
        uint32 l1ChainId_,
        address l1Escrow_,
        address zkUSDCe_,
        address zkBWUSDC_
    ) {
        // TODO: TBI
        bridge = bridge_;
        l1ChainId = l1ChainId_;
        l1Escrow = l1Escrow_;
        zkUSDCe = zkUSDCe_;
        zkBWUSDC = zkBWUSDC_;
    }

    function convert(uint256 amount, address receiver) external {
        // User calls convert() on NativeConverter,
        // BridgeWrappedUSDC is transferred to NativeConverter
        // NativeConverter calls mint() on NativeUSDC which mints
        // new supply to the correct address.

        // TODO: TBI

        require(receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        // TODO: BridgeWrappedUSDC is transferred to NativeConverter
        // zkBWUSDC.safeTransferFrom(msg.sender, address(this), amount);

        // TODO: calls mint() on NativeUSDC which mints new supply to the correct address.
        // zkUSDCe.mint(receiver, amount);
    }

    function migrate() external {
        // Anyone can call migrate() on NativeConverter to
        // have all BridgeWrappedUSDC withdrawn via the zkEVMBridge
        // moving the L1_USDC held in the zkEVMBridge to L1Escrow

        // TODO: TBD and TBI

        bytes memory data = abi.encode("TBD");
        // bridge.bridgeMessage(l1ChainId, l1Escrow, true, data); // TODO: forceUpdateGlobalExitRoot TBD
    }
}
