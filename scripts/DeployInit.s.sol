// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Script.sol";

import {LibDeployInit} from "./DeployInitHelpers.sol";

import "../src/L1EscrowProxy.sol";
import "../src/L1Escrow.sol";
import "../src/NativeConverterProxy.sol";
import "../src/NativeConverter.sol";
import "../src/ZkMinterBurnerProxy.sol";
import "../src/ZkMinterBurner.sol";

/// @title DeployInit
/// @notice A script for deploying, initializing, and setting the access controls
/// @notice for the 3 contracts that comprise the LXLY system:
/// @notice 1) L1Escrow
/// @notice 2) ZkMinterBurner
/// @notice 3) NativeConverter
contract DeployInit is Script {
    uint256 l1ForkId = vm.createFork(vm.envString("L1_RPC_URL"));
    uint256 l2ForkId = vm.createFork(vm.envString("L2_RPC_URL"));

    address bridge = vm.envAddress("ADDRESS_LXLY_BRIDGE");
    uint32 l1NetworkId = uint32(vm.envUint("L1_NETWORK_ID"));
    uint32 l2NetworkId = uint32(vm.envUint("L2_NETWORK_ID"));

    address l1Usdc = vm.envAddress("ADDRESS_L1_USDC");
    address zkUSDCe = vm.envAddress("ADDRESS_L2_USDC"); // ATTN: needs to be deployed beforehand zkUsdc
    address zkBWUSDC = vm.envAddress("ADDRESS_L2_WUSDC");

    /// @notice the address that is able to upgrade the proxy contract's implementation contract
    address admin = vm.envAddress("ADDRESS_PROXY_ADMIN");
    /// @notice the address that is able to pause and unpause the l1Escrow, zkMinterBurner, and nativeConverter contracts
    address owner = vm.envAddress("ADDRESS_OWNER");

    function run() external {
        // deploy L1 contract
        vm.selectFork(l1ForkId);
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        address l1EscrowProxy = LibDeployInit.deployL1Contracts();
        vm.stopBroadcast();

        // deploy L2 contracts
        vm.selectFork(l2ForkId);
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        (
            address minterBurnerProxy,
            address nativeConverterProxy
        ) = LibDeployInit.deployL2Contracts();
        vm.stopBroadcast();

        // init L1 contract
        vm.selectFork(l1ForkId);
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        L1Escrow l1Escrow = LibDeployInit.initL1Contracts(
            owner,
            admin,
            l2NetworkId,
            bridge,
            l1EscrowProxy,
            minterBurnerProxy,
            l1Usdc
        );
        vm.stopBroadcast();

        // init L2 contracts
        vm.selectFork(l2ForkId);
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        (
            ZkMinterBurner minterBurner,
            NativeConverter nativeConverter
        ) = LibDeployInit.initL2Contracts(
                owner,
                admin,
                l1NetworkId,
                bridge,
                l1EscrowProxy,
                minterBurnerProxy,
                nativeConverterProxy,
                zkUSDCe,
                zkBWUSDC
            );
        vm.stopBroadcast();

        console.log("L1_ESCROW_PROXY=%s", address(l1Escrow));
        console.log("ZK_MINTER_BURNER_PROXY=%s", address(minterBurner));
        console.log("NATIVE_CONVERTER_PROXY=%s", address(nativeConverter));
    }
}
