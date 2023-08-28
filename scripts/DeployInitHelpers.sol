// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {CommonBase} from "lib/forge-std/src/Base.sol";

import "../src/L1EscrowProxy.sol";
import "../src/L1Escrow.sol";
import "../src/NativeConverterProxy.sol";
import "../src/NativeConverter.sol";
import "../src/ZkMinterBurnerProxy.sol";
import "../src/ZkMinterBurner.sol";

/// @title LibDeployInit
/// @dev The contract that actually implements the logic for deploying
/// the zkUSDC-e system contracts
library LibDeployInit {
    function deployL1Contracts() internal returns (address l1eProxy) {
        // deploy implementation
        L1Escrow l1Escrow = new L1Escrow();
        // deploy proxy
        L1EscrowProxy l1EscrowProxy = new L1EscrowProxy(address(l1Escrow), "");

        // return address of the proxy
        l1eProxy = address(l1EscrowProxy);
    }

    function deployL2Contracts()
        internal
        returns (address mbProxy, address ncProxy)
    {
        // deploy implementation
        ZkMinterBurner minterBurnerImpl = new ZkMinterBurner();
        // deploy proxy
        ZkMinterBurnerProxy minterBurnerProxy = new ZkMinterBurnerProxy(
            address(minterBurnerImpl),
            ""
        );

        // deploy implementation
        NativeConverter nativeConverter = new NativeConverter();
        // deploy proxy
        NativeConverterProxy nativeConverterProxy = new NativeConverterProxy(
            address(nativeConverter),
            ""
        );

        // return addresses of the proxies
        mbProxy = address(minterBurnerProxy);
        ncProxy = address(nativeConverterProxy);
    }

    function initL1Contracts(
        address owner,
        address admin,
        uint32 l2NetworkId,
        address bridge,
        address l1EscrowProxy,
        address minterBurnerProxy,
        address l1Usdc
    ) internal returns (L1Escrow l1Escrow) {
        // get a reference to the proxy, with the impl's abi, and then call initialize
        l1Escrow = L1Escrow(l1EscrowProxy);
        l1Escrow.initialize(
            owner,
            admin,
            bridge,
            l2NetworkId,
            minterBurnerProxy,
            l1Usdc
        );
    }

    function initL2Contracts(
        address owner,
        address admin,
        uint32 l1NetworkId,
        address bridge,
        address l1EscrowProxy,
        address minterBurnerProxy,
        address nativeConverterProxy,
        address zkUSDCe,
        address zkBWUSDC
    )
        internal
        returns (ZkMinterBurner minterBurner, NativeConverter nativeConverter)
    {
        // get a reference to the proxy, with the impl's abi, and then call initialize
        minterBurner = ZkMinterBurner(minterBurnerProxy);
        minterBurner.initialize(
            owner,
            admin,
            bridge,
            l1NetworkId,
            l1EscrowProxy,
            zkUSDCe
        );

        // get a reference to the proxy, with the impl's abi, and then call initialize
        nativeConverter = NativeConverter(nativeConverterProxy);
        nativeConverter.initialize(
            owner,
            admin,
            bridge,
            l1NetworkId,
            l1EscrowProxy,
            zkUSDCe,
            zkBWUSDC
        );
    }
}
