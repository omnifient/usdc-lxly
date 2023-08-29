// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {CommonAdminOwner} from "./CommonAdminOwner.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";
import {LibPermit} from "./helpers/LibPermit.sol";

// This contract will receive BridgeWrappedUSDC on zkEVM and issue USDC.e on zkEVM.
// This contract will hold the minter role giving it the ability to mint USDC.e based on inflows of BridgeWrappedUSDC.
// This contract will also have a permissionless publicly callable function called “migrate” which when called will
// withdraw all BridgedWrappedUSDC to L1 via the LXLY bridge. The beneficiary address will be the L1Escrow,
// thus migrating the supply and settling the balance.
contract NativeConverter is CommonAdminOwner {
    using SafeERC20Upgradeable for IUSDC;

    event Convert(address indexed from, address indexed to, uint256 amount);
    event Migrate(uint256 amount);

    /// @notice the PolygonZkEVMBridge deployed on the zkEVM
    IPolygonZkEVMBridge public bridge;
    uint32 public l1NetworkId;
    address public l1Escrow;
    /// @notice The L2 USDC-e deployed on the zkEVM
    IUSDC public zkUSDCe;
    /// @notice The default L2 USDC TokenWrapped token deployed on the zkEVM
    IUSDC public zkBWUSDC;

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
        address zkUSDCe_,
        address zkBWUSDC_
    ) external onlyProxy onlyAdmin initializer {
        require(bridge_ != address(0), "INVALID_BRIDGE");
        require(l1EscrowProxy_ != address(0), "INVALID_L1ESCROW");
        require(zkUSDCe_ != address(0), "INVALID_USDC_E");
        require(zkBWUSDC_ != address(0), "INVALID_BW_UDSC");
        require(owner_ != address(0), "INVALID_OWNER");
        require(admin_ != address(0), "INVALID_ADMIN");

        __CommonAdminOwner_init();

        _transferOwnership(owner_);
        _changeAdmin(admin_);

        bridge = IPolygonZkEVMBridge(bridge_);
        l1NetworkId = l1NetworkId_;
        l1Escrow = l1EscrowProxy_;
        zkUSDCe = IUSDC(zkUSDCe_);
        zkBWUSDC = IUSDC(zkBWUSDC_);
    }

    function convert(
        address receiver,
        uint256 amount,
        bytes calldata permitData
    ) external whenNotPaused {
        // User calls convert() on NativeConverter,
        // BridgeWrappedUSDC is transferred to NativeConverter
        // NativeConverter calls mint() on NativeUSDC which mints
        // new supply to the correct address.

        require(receiver != address(0), "INVALID_RECEIVER");
        require(amount > 0, "INVALID_AMOUNT");

        if (permitData.length > 0)
            LibPermit.permit(address(zkBWUSDC), amount, permitData);

        // transfer the wrapped usdc to the converter, and mint back native usdc
        zkBWUSDC.safeTransferFrom(msg.sender, address(this), amount);
        zkUSDCe.mint(receiver, amount);

        emit Convert(msg.sender, receiver, amount);
    }

    function migrate() external whenNotPaused {
        // Anyone can call migrate() on NativeConverter to
        // have all zkBridgeWrappedUSDC withdrawn via the PolygonZkEVMBridge
        // moving the L1_USDC held in the PolygonZkEVMBridge to L1Escrow

        uint256 amount = zkBWUSDC.balanceOf(address(this));

        if (amount > 0) {
            zkBWUSDC.approve(address(bridge), amount);

            bridge.bridgeAsset(
                l1NetworkId,
                l1Escrow,
                amount,
                address(zkBWUSDC),
                true, // forceUpdateGlobalExitRoot
                "" // empty permitData because we're doing approve
            );

            emit Migrate(amount);
        }
    }
}
