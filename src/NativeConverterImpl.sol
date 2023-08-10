// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@zkevm/interfaces/IPolygonZkEVMBridge.sol";

import {IUSDC} from "./interfaces/IUSDC.sol";

// This contract will receive BridgeWrappedUSDC on zkEVM and issue USDC.e on zkEVM.
// This contract will hold the minter role giving it the ability to mint USDC.e based on inflows of BridgeWrappedUSDC.
// This contract will also have a permissionless publicly callable function called “migrate” which when called will
// withdraw all BridgedWrappedUSDC to L1 via the LXLY bridge. The beneficiary address will be the L1Escrow,
// thus migrating the supply and settling the balance.
contract NativeConverterImpl is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IUSDC;

    event Convert(address indexed from, address indexed to, uint256 amount);
    event Migrate(uint256 amount);

    IPolygonZkEVMBridge public bridge;
    uint32 public l1NetworkId;
    address public l1Escrow;
    IUSDC public zkUSDCe;
    IUSDC public zkBWUSDC;

    constructor() {
        // override default OZ behaviour that sets msg.sender as the owner
        // set the owner of the implementation to an address that can not change anything
        _transferOwnership(address(1));
    }

    function initialize(
        address owner_,
        address bridge_,
        uint32 l1NetworkId_,
        address l1Escrow_,
        address zkUSDCe_,
        address zkBWUSDC_
    ) external onlyProxy initializer {
        require(msg.sender == _getAdmin(), "NOT_ADMIN");
        require(bridge_ != address(0), "INVALID_ADDRESS");
        require(l1Escrow_ != address(0), "INVALID_ADDRESS");
        require(zkUSDCe_ != address(0), "INVALID_ADDRESS");
        require(zkBWUSDC_ != address(0), "INVALID_ADDRESS");
        require(owner_ != address(0), "INVALID_ADDRESS");

        __Ownable_init(); // ATTN: we override this later
        __Pausable_init(); // NOOP
        __UUPSUpgradeable_init(); // NOOP

        _transferOwnership(owner_);

        bridge = IPolygonZkEVMBridge(bridge_);
        l1NetworkId = l1NetworkId_;
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
