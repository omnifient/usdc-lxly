// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "lib/forge-std/src/Script.sol";

import "../src/L1EscrowImpl.sol";
import "../src/NativeConverterImpl.sol";
import "../src/ZkMinterBurnerImpl.sol";

contract InitL1Contracts is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // NOTE: we're just using the interface definition of the impl to fool the compiler
        L1EscrowImpl l1eProxy = L1EscrowImpl(
            payable(vm.envAddress("ADDRESS_L1_ESCROW_PROXY"))
        );

        // initialize the l1 escrow contract through the proxy
        l1eProxy.initialize(
            vm.envAddress("ADDRESS_LXLY_BRIDGE"),
            uint32(vm.envUint("L2_CHAIN_ID")),
            vm.envAddress("ADDRESS_ZK_MINTER_BURNER_PROXY"),
            vm.envAddress("ADDRESS_L1_USDC")
        );

        vm.stopBroadcast();
    }
}

contract InitL2Contracts is Script {
    function run() external {
        address lxlyBridge = vm.envAddress("ADDRESS_LXLY_BRIDGE");
        address zkUsdc = vm.envAddress("ADDRESS_L2_USDC"); // ATTN: needs to be deployed beforehand zkUsdc
        address zkWrappedUsdc = vm.envAddress("ADDRESS_L2_WUSDC");
        uint32 polygonChainId = uint32(vm.envUint("L1_CHAIN_ID"));
        address l1Escrow = vm.envAddress("ADDRESS_L1_ESCROW_PROXY");

        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // NOTE: we're just using the interface definition of the impl to fool the compiler
        ZkMinterBurnerImpl zkmbProxy = ZkMinterBurnerImpl(
            payable(vm.envAddress("ADDRESS_ZK_MINTER_BURNER_PROXY"))
        );
        // initialize the minter burner
        zkmbProxy.initialize(lxlyBridge, polygonChainId, l1Escrow, zkUsdc);

        // NOTE: we're just using the interface definition of the impl to fool the compiler
        NativeConverterImpl ncProxy = NativeConverterImpl(
            payable(vm.envAddress("ADDRESS_NATIVE_CONVERTER_PROXY"))
        );
        // initialize the native converter
        ncProxy.initialize(
            lxlyBridge,
            polygonChainId,
            l1Escrow,
            zkUsdc,
            zkWrappedUsdc
        );

        vm.stopBroadcast();
    }
}
