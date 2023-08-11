// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Script.sol";

import {LibDeployInit} from "./DeployInitHelpers.sol";

import "../src/L1EscrowProxy.sol";
import "../src/L1EscrowImpl.sol";
import "../src/NativeConverterProxy.sol";
import "../src/NativeConverterImpl.sol";
import "../src/ZkMinterBurnerProxy.sol";
import "../src/ZkMinterBurnerImpl.sol";

contract DeployInit is Script {
    uint256 l1ForkId = vm.createFork(vm.envString("L1_RPC_URL"));
    uint256 l2ForkId = vm.createFork(vm.envString("L2_RPC_URL"));

    address bridge = vm.envAddress("ADDRESS_LXLY_BRIDGE");
    uint32 l1NetworkId = uint32(vm.envUint("L1_NETWORK_ID"));
    uint32 l2NetworkId = uint32(vm.envUint("L2_NETWORK_ID"));

    address l1Usdc = vm.envAddress("ADDRESS_L1_USDC");
    address l2Usdc = vm.envAddress("ADDRESS_L2_USDC"); // ATTN: needs to be deployed beforehand zkUsdc
    address l2WrappedUsdc = vm.envAddress("ADDRESS_L2_WUSDC");

    address admin = vm.envAddress("ADDRESS_PROXY_ADMIN");
    address owner = vm.envAddress("ADDRESS_OWNER");

    function run() external {
        // deploy L1 contract
        vm.selectFork(l1ForkId);
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        address l1EscrowProxy = LibDeployInit.deployL1Contracts(admin);
        vm.stopBroadcast();

        // deploy L2 contracts
        vm.selectFork(l2ForkId);
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        (
            address minterBurnerProxy,
            address nativeConverterProxy
        ) = LibDeployInit.deployL2Contracts(admin);
        vm.stopBroadcast();

        // init L1 contract
        vm.selectFork(l1ForkId);
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        L1EscrowImpl l1Escrow = LibDeployInit.initL1Contracts(
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
            ZkMinterBurnerImpl minterBurner,
            NativeConverterImpl nativeConverter
        ) = LibDeployInit.initL2Contracts(
                l1NetworkId,
                bridge,
                l1EscrowProxy,
                minterBurnerProxy,
                nativeConverterProxy,
                l2Usdc,
                l2WrappedUsdc
            );
        vm.stopBroadcast();

        console.log("L1_ESCROW_PROXY=%s", address(l1Escrow));
        console.log("ZK_MINTER_BURNER_PROXY=%s", address(minterBurner));
        console.log("NATIVE_CONVERTER_PROXY=%s", address(nativeConverter));
    }
}
