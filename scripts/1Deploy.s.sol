// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Script.sol";

import "../src/L1EscrowProxy.sol";
import "../src/L1EscrowImpl.sol";
import "../src/NativeConverterProxy.sol";
import "../src/NativeConverterImpl.sol";
import "../src/ZkMinterBurnerProxy.sol";
import "../src/ZkMinterBurnerImpl.sol";

// This script (only) DEPLOYS the L1Escrow contract to L1
contract DeployL1Contracts is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // deploy implementation
        L1EscrowImpl l1eImpl = new L1EscrowImpl();
        // deploy proxy
        L1EscrowProxy l1eProxy = new L1EscrowProxy(
            vm.envAddress("ADDRESS_PROXY_ADMIN"),
            address(l1eImpl),
            ""
        );

        console.log("deployment successful!");

        console.log("ADDRESS_L1_ESCROW_PROXY=%s", address(l1eProxy));
        console.log("L1EscrowImpl", address(l1eImpl));
        vm.stopBroadcast();
    }
}

// This script (only) DEPLOYS the ZkMinterBurner and NativeConverter contracts to L2
contract DeployL2Contracts is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // deploy L2 implementations
        NativeConverterImpl ncImpl = new NativeConverterImpl();
        ZkMinterBurnerImpl mbImpl = new ZkMinterBurnerImpl();

        // deploy L2 proxies
        NativeConverterProxy ncProxy = new NativeConverterProxy(
            vm.envAddress("ADDRESS_PROXY_ADMIN"),
            address(ncImpl),
            ""
        );
        ZkMinterBurnerProxy mbProxy = new ZkMinterBurnerProxy(
            vm.envAddress("ADDRESS_PROXY_ADMIN"),
            address(mbImpl),
            ""
        );

        console.log("deployment successful!");

        console.log("ADDRESS_ZK_MINTER_BURNER_PROXY=%s", address(mbProxy));
        console.log("ZkMinterBurnerImpl", address(mbImpl));

        console.log("ADDRESS_NATIVE_CONVERTER_PROXY=%s", address(ncProxy));
        console.log("NativeConverterImpl", address(ncImpl));

        vm.stopBroadcast();
    }
}
