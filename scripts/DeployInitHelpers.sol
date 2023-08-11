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
        address owner
    ) internal returns (address l1eProxy) {
        // deploy implementation
        L1EscrowImpl l1EscrowImpl = new L1EscrowImpl();
        // deploy proxy
        L1EscrowProxy l1EscrowProxy = new L1EscrowProxy(
            owner,
            address(l1EscrowImpl),
            ""
        );

        // return address of the proxy
        l1eProxy = address(l1EscrowProxy);
    }

    function deployL2Contracts(
        address owner
    ) internal returns (address mbProxy, address ncProxy) {
        // deploy implementation
        ZkMinterBurnerImpl minterBurnerImpl = new ZkMinterBurnerImpl();
        // deploy proxy
        ZkMinterBurnerProxy minterBurnerProxy = new ZkMinterBurnerProxy(
            owner,
            address(minterBurnerImpl),
            ""
        );

        // deploy implementation
        NativeConverterImpl nativeConverterImpl = new NativeConverterImpl();
        // deploy proxy
        NativeConverterProxy nativeConverterProxy = new NativeConverterProxy(
            owner,
            address(nativeConverterImpl),
            ""
        );

        // return addresses of the proxies
        mbProxy = address(minterBurnerProxy);
        ncProxy = address(nativeConverterProxy);
    }

    function initL1Contracts(
        uint32 l2NetworkId,
        address bridge,
        address l1EscrowProxy,
        address minterBurnerProxy,
        address l1Usdc
    ) internal returns (L1EscrowImpl l1Escrow) {
        // get a reference to the proxy, with the impl's abi, and then call initialize
        l1Escrow = L1EscrowImpl(l1EscrowProxy);
        l1Escrow.initialize(bridge, l2NetworkId, minterBurnerProxy, l1Usdc);
    }

    function initL2Contracts(
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
        minterBurner.initialize(bridge, l1NetworkId, l1EscrowProxy, l2Usdc);

        // get a reference to the proxy, with the impl's abi, and then call initialize
        nativeConverter = NativeConverterImpl(nativeConverterProxy);
        nativeConverter.initialize(
            bridge,
            l1NetworkId,
            l1EscrowProxy,
            l2Usdc,
            l2Wusdc
        );
    }
}

contract DeployInitHelpers is CommonBase {
    // NOTE: these fields are only used by deployInit
    uint256 internal _l1ForkId;
    uint256 internal _l2ForkId;
    uint32 internal _l1NetworkId;
    uint32 internal _l2NetworkId;
    address internal _bridge;
    address internal _l1Usdc;
    address internal _l2Usdc;
    address internal _l2Wusdc;

    constructor(
        uint256 l1ForkId,
        uint256 l2ForkId,
        uint32 l1NetworkId,
        uint32 l2NetworkId,
        address bridge,
        address l1Usdc,
        address l2Usdc,
        address l2Wusdc
    ) {
        // we need a lot of arguments for deploy+init, so setting some in ctor
        _l1ForkId = l1ForkId;
        _l2ForkId = l2ForkId;
        _l1NetworkId = l1NetworkId;
        _l2NetworkId = l2NetworkId;
        _bridge = bridge;
        _l1Usdc = l1Usdc;
        _l2Usdc = l2Usdc;
        _l2Wusdc = l2Wusdc;
    }

    function deployInit(
        address deployer,
        address owner
    )
        external
        returns (
            L1EscrowImpl l1Escrow,
            ZkMinterBurnerImpl minterBurner,
            NativeConverterImpl nativeConverter
        )
    {
        vm.startPrank(deployer);

        // deploy L1 contract
        vm.selectFork(_l1ForkId);
        address l1EscrowProxy = LibDeployInit.deployL1Contracts(owner);

        // deploy L2 contracts
        vm.selectFork(_l2ForkId);
        (
            address minterBurnerProxy,
            address nativeConverterProxy
        ) = LibDeployInit.deployL2Contracts(owner);

        // init L1 contract
        vm.selectFork(_l1ForkId);
        l1Escrow = LibDeployInit.initL1Contracts(
            _l2NetworkId,
            _bridge,
            l1EscrowProxy,
            minterBurnerProxy,
            _l1Usdc
        );

        // init L2 contracts
        vm.selectFork(_l2ForkId);
        (minterBurner, nativeConverter) = LibDeployInit.initL2Contracts(
            _l1NetworkId,
            _bridge,
            l1EscrowProxy,
            minterBurnerProxy,
            nativeConverterProxy,
            _l2Usdc,
            _l2Wusdc
        );

        vm.stopPrank();
    }
}
