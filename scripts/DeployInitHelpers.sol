// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {CommonBase} from "lib/forge-std/src/Base.sol";

import "../src/L1EscrowProxy.sol";
import "../src/L1EscrowImpl.sol";
import "../src/NativeConverterProxy.sol";
import "../src/NativeConverterImpl.sol";
import "../src/ZkMinterBurnerProxy.sol";
import "../src/ZkMinterBurnerImpl.sol";

library LibDeployInit {
    function deployL1Contracts(
        address admin
    ) internal returns (address l1eProxy) {
        // deploy implementation
        L1EscrowImpl l1EscrowImpl = new L1EscrowImpl();
        // deploy proxy
        L1EscrowProxy l1EscrowProxy = new L1EscrowProxy(
            admin,
            address(l1EscrowImpl),
            ""
        );

        // return address of the proxy
        l1eProxy = address(l1EscrowProxy);
    }

    function deployL2Contracts(
        address admin
    ) internal returns (address mbProxy, address ncProxy) {
        // deploy implementation
        ZkMinterBurnerImpl minterBurnerImpl = new ZkMinterBurnerImpl();
        // deploy proxy
        ZkMinterBurnerProxy minterBurnerProxy = new ZkMinterBurnerProxy(
            admin,
            address(minterBurnerImpl),
            ""
        );

        // deploy implementation
        NativeConverterImpl nativeConverterImpl = new NativeConverterImpl();
        // deploy proxy
        NativeConverterProxy nativeConverterProxy = new NativeConverterProxy(
            admin,
            address(nativeConverterImpl),
            ""
        );

        // return addresses of the proxies
        mbProxy = address(minterBurnerProxy);
        ncProxy = address(nativeConverterProxy);
    }

    function initL1Contracts(
        address owner,
        uint32 l2NetworkId,
        address bridge,
        address l1EscrowProxy,
        address minterBurnerProxy,
        address l1Usdc
    ) internal returns (L1EscrowImpl l1Escrow) {
        // get a reference to the proxy, with the impl's abi, and then call initialize
        l1Escrow = L1EscrowImpl(l1EscrowProxy);
        l1Escrow.initialize(
            owner,
            bridge,
            l2NetworkId,
            minterBurnerProxy,
            l1Usdc
        );
    }

    function initL2Contracts(
        address owner,
        uint32 l1NetworkId,
        address bridge,
        address l1EscrowProxy,
        address minterBurnerProxy,
        address nativeConverterProxy,
        address l2Usdc,
        address l2Wusdc
    )
        internal
        returns (
            ZkMinterBurnerImpl minterBurner,
            NativeConverterImpl nativeConverter
        )
    {
        // get a reference to the proxy, with the impl's abi, and then call initialize
        minterBurner = ZkMinterBurnerImpl(minterBurnerProxy);
        minterBurner.initialize(
            owner,
            bridge,
            l1NetworkId,
            l1EscrowProxy,
            l2Usdc
        );

        // get a reference to the proxy, with the impl's abi, and then call initialize
        nativeConverter = NativeConverterImpl(nativeConverterProxy);
        nativeConverter.initialize(
            owner,
            bridge,
            l1NetworkId,
            l1EscrowProxy,
            l2Usdc,
            l2Wusdc
        );
    }
}
