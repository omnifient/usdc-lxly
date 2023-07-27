// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/StdUtils.sol";
import "lib/forge-std/src/Test.sol";

import "../src/L1EscrowProxy.sol";
import "../src/L1EscrowImpl.sol";
import "../src/NativeConverterProxy.sol";
import "../src/NativeConverterImpl.sol";
import "../src/ZkMinterBurnerProxy.sol";
import "../src/ZkMinterBurnerImpl.sol";

contract Base is Test {
    uint256 internal constant _ONE_MILLION_USDC = 10 ** 6 * 10 ** 6;

    /* ================= FIELDS ================= */
    uint256 internal _l1Fork;
    uint256 internal _l2Fork;
    uint32 internal _l1ChainId;
    uint32 internal _l2ChainId;

    // addresses
    address internal _alice;

    address internal _owner;
    address internal _bridge;
    address internal _l1Usdc;
    address internal _l2Usdc;
    address internal _l2Wusdc;

    // helper variables
    IERC20 _erc20L1Usdc;
    IERC20 _erc20L2Usdc;
    IERC20 _erc20L2Wusdc;

    // L1 contracts
    L1EscrowImpl private _l1EscrowImpl;
    L1EscrowProxy private _l1EscrowProxy;
    L1EscrowImpl internal _l1Escrow; // exposed to subclasses

    // L2 contracts
    NativeConverterImpl private _nativeConverterImpl;
    NativeConverterProxy private _nativeConverterProxy;
    NativeConverterImpl internal _nativeConverter; // exposed to subclasses
    ZkMinterBurnerImpl private _minterBurnerImpl;
    ZkMinterBurnerProxy private _minterBurnerProxy;
    ZkMinterBurnerImpl internal _minterBurner; // exposed to subclasses

    /* ================= SETUP ================= */
    function setUp() public {
        // create the forks
        _l1Fork = vm.createFork(vm.envString("TEST_L1_RPC_URL"));
        _l2Fork = vm.createFork(vm.envString("TEST_L2_RPC_URL"));
        _l1ChainId = uint32(vm.envUint("L1_CHAIN_ID"));
        _l2ChainId = uint32(vm.envUint("L2_CHAIN_ID"));

        // retrieve the addresses
        _owner = vm.envAddress("TEST_ADDRESS_OWNER");
        _bridge = vm.envAddress("ADDRESS_LXLY_BRIDGE");
        _l1Usdc = vm.envAddress("ADDRESS_L1_USDC");
        _l2Usdc = vm.envAddress("ADDRESS_L2_USDC");
        _l2Wusdc = vm.envAddress("ADDRESS_L2_WUSDC");
        _erc20L1Usdc = IERC20(_l1Usdc);
        _erc20L2Usdc = IERC20(_l2Usdc);
        _erc20L2Wusdc = IERC20(_l2Wusdc);

        // deploy and initialize contracts
        vm.startPrank(_owner);
        _deployL1();
        _deployL2();

        _initL1();
        _initL2();
        vm.stopPrank();

        // TODO: assign minter roles

        // fund alice with L1_USDC and L2_WUSDC
        _alice = vm.addr(1);
        vm.selectFork(_l1Fork);
        deal(_l1Usdc, _alice, _ONE_MILLION_USDC);

        vm.selectFork(_l2Fork);
        deal(_l2Wusdc, _alice, _ONE_MILLION_USDC);
    }

    /* ================= HELPERS ================= */
    function _deployL1() internal {
        vm.selectFork(_l1Fork);
        _l1EscrowImpl = new L1EscrowImpl();
        _l1EscrowProxy = new L1EscrowProxy(_owner, address(_l1EscrowImpl), "");
    }

    function _deployL2() internal {
        vm.selectFork(_l2Fork);
        _nativeConverterImpl = new NativeConverterImpl();
        _nativeConverterProxy = new NativeConverterProxy(
            _owner,
            address(_nativeConverterImpl),
            ""
        );

        _minterBurnerImpl = new ZkMinterBurnerImpl();
        _minterBurnerProxy = new ZkMinterBurnerProxy(
            _owner,
            address(_minterBurnerImpl),
            ""
        );
    }

    function _initL1() internal {
        vm.selectFork(_l1Fork);
        _l1Escrow = L1EscrowImpl(address(_l1EscrowProxy));
        _l1Escrow.initialize(
            _bridge,
            _l2ChainId,
            address(_minterBurnerProxy),
            _l1Usdc
        );
    }

    function _initL2() internal {
        vm.selectFork(_l2Fork);
        _minterBurner = ZkMinterBurnerImpl(address(_minterBurnerProxy));
        _minterBurner.initialize(
            _bridge,
            _l1ChainId,
            address(_l1EscrowProxy),
            _l2Usdc
        );

        _nativeConverter = NativeConverterImpl(address(_nativeConverterProxy));
        _nativeConverter.initialize(
            _bridge,
            _l1ChainId,
            address(_l1EscrowProxy),
            _l2Usdc,
            _l2Wusdc
        );
    }

    function _toUSDC(uint256 v) internal pure returns (uint256) {
        return v * 10 ** 6;
    }
}
