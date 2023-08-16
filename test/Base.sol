// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "lib/forge-std/src/Test.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {LibDeployInit} from "../scripts/DeployInitHelpers.sol";
import "../src/mocks/MockBridge.sol";
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
    uint32 internal _l1NetworkId;
    uint32 internal _l2NetworkId;

    // addresses
    address internal _alice;
    address internal _bob;

    address private _deployerOwnerAdmin;
    address internal _bridge;
    address internal _l1Usdc;
    address internal _l2Usdc;
    address internal _l2Wusdc;

    // helper variables
    IERC20 internal _erc20L1Usdc;
    IERC20 internal _erc20L2Usdc;
    IERC20 internal _erc20L2Wusdc;

    // L1 contracts
    L1EscrowImpl internal _l1Escrow;

    // L2 contracts
    ZkMinterBurnerImpl internal _minterBurner;
    NativeConverterImpl internal _nativeConverter;

    /* ================= EVENTS ================= */
    // copy of PolygonZKEVMBridge.BridgeEvent
    event BridgeEvent(
        uint8 leafType,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes metadata,
        uint32 depositCount
    );

    // copy of NativeConverterImpl.Convert
    event Convert(address indexed from, address indexed to, uint256 amount);

    // copy of L1EscrowImpl.Deposit
    event Deposit(address indexed from, address indexed to, uint256 amount);

    // copy of NativeConverterImpl.Migrate
    event Migrate(uint256 amount);

    // copy of ZkMinterBurner.Withdraw
    event Withdraw(address indexed from, address indexed to, uint256 amount);

    /* ================= SETUP ================= */
    function setUp() public virtual {
        // create the forks
        _l1Fork = vm.createFork(vm.envString("L1_RPC_URL"));
        _l2Fork = vm.createFork(vm.envString("L2_RPC_URL"));
        _l1NetworkId = uint32(vm.envUint("L1_NETWORK_ID"));
        _l2NetworkId = uint32(vm.envUint("L2_NETWORK_ID"));

        // retrieve the addresses
        _bridge = vm.envAddress("ADDRESS_LXLY_BRIDGE");
        _l1Usdc = vm.envAddress("ADDRESS_L1_USDC");
        _l2Usdc = vm.envAddress("ADDRESS_L2_USDC");
        _l2Wusdc = vm.envAddress("ADDRESS_L2_WUSDC");
        _erc20L1Usdc = IERC20(_l1Usdc);
        _erc20L2Usdc = IERC20(_l2Usdc);
        _erc20L2Wusdc = IERC20(_l2Wusdc);

        _deployerOwnerAdmin = vm.addr(8);
        _alice = vm.addr(1);
        _bob = vm.addr(2);

        // deploy and initialize contracts
        _deployMockBridge();
        _deployInitContracts();

        // fund alice with L1_USDC and L2_WUSDC
        vm.selectFork(_l1Fork);
        deal(_l1Usdc, _alice, _ONE_MILLION_USDC);

        vm.selectFork(_l2Fork);
        deal(_l2Wusdc, _alice, _ONE_MILLION_USDC);
    }

    /* ================= HELPERS ================= */
    function _assertUsdcSupplyAndBalancesMatch() internal {
        vm.selectFork(_l1NetworkId);
        uint256 l1EscrowBalance = _erc20L1Usdc.balanceOf(address(_l1Escrow));

        vm.selectFork(_l2NetworkId);
        uint256 l2TotalSupply = _erc20L2Usdc.totalSupply();
        uint256 wUsdcConverterBalance = _erc20L2Wusdc.balanceOf(
            address(_nativeConverter)
        );

        // zkUsdc.totalSupply <= l1Usdc.balanceOf(l1Escrow) + bwUSDC.balanceOf(nativeConverter)
        assertLe(l2TotalSupply, l1EscrowBalance + wUsdcConverterBalance);
    }

    function _claimBridgeMessage(uint256 from, uint256 to) internal {
        MockBridge b = MockBridge(_bridge);

        vm.selectFork(from);
        (
            uint32 originNetwork,
            address originAddress,
            uint32 destinationNetwork,
            address destinationAddress,
            uint256 amount,
            bytes memory metadata
        ) = b.lastBridgeMessage();
        // proof can be empty because our MockBridge bypasses the merkle tree verification
        // i.e. _verifyLeaf is always successful
        bytes32[32] memory proof;

        vm.selectFork(to);
        b.claimMessage(
            proof,
            uint32(b.depositCount()),
            "",
            "",
            originNetwork,
            originAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata
        );
    }

    function _claimBridgeAsset(uint256 from, uint256 to) internal {
        MockBridge b = MockBridge(_bridge);

        vm.selectFork(from);
        (
            uint32 originNetwork,
            address originTokenAddress,
            uint32 destinationNetwork,
            address destinationAddress,
            uint256 amount,
            bytes memory metadata
        ) = b.lastBridgeMessage();
        // proof and index can be empty because our MockBridge bypasses the merkle tree verification
        // i.e. _verifyLeaf is always successful
        bytes32[32] memory proof;
        uint32 index;

        vm.selectFork(to);
        b.claimAsset(
            proof,
            index,
            "",
            "",
            originNetwork,
            originTokenAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata
        );
    }

    function _createPermitData(
        address owner,
        address spender,
        address token,
        uint256 amount
    ) internal view returns (bytes memory) {
        uint256 deadline = block.timestamp + 3600;

        // bytes32 domainSeparator = keccak256(
        //     abi.encode(
        //         keccak256(
        //             "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        //         ),
        //         keccak256(bytes("USD Coin")),
        //         keccak256(bytes("2")), // NOTE: L1_USDC (and L2_USDC) uses 2 for version, while L2_WUSDC uses 1 for version
        //         block.chainid,
        //         token
        //     )
        // );

        // using hardcoded hashes for the tests because of the different behaviour between the tokens
        bytes32 domainSeparator;
        if (token == _l1Usdc)
            domainSeparator = 0x06c37168a7db5138defc7866392bb87a741f9b3d104deb5094588ce041cae335;
        else if (token == _l2Usdc)
            domainSeparator = 0x32cb9f7a37b849025be12e9700a52a2ee65ac0486dc394e301d499c167295793;
        else if (token == _l2Wusdc)
            domainSeparator = 0xb8635a253867c90fc062ea6e136320a069a19b956695db78f8be4224e1d7c462;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                owner,
                spender,
                amount,
                0, // permit nonce for owner
                deadline
            )
        );
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest); // ATTN: 1 is alice's private key
        bytes4 permitSig = 0xd505accf;

        return
            abi.encodeWithSelector(
                permitSig,
                owner,
                spender,
                amount,
                deadline,
                v,
                r,
                s
            );
    }

    function _deployInitContracts() internal {
        vm.startPrank(_deployerOwnerAdmin);

        // deploy L1 contract
        vm.selectFork(_l1Fork);
        address l1EscrowProxy = LibDeployInit.deployL1Contracts(
            _deployerOwnerAdmin // admin
        );

        // deploy L2 contracts
        vm.selectFork(_l2Fork);
        (
            address minterBurnerProxy,
            address nativeConverterProxy
        ) = LibDeployInit.deployL2Contracts(
                _deployerOwnerAdmin // admin
            );

        // init L1 contract
        vm.selectFork(_l1Fork);
        _l1Escrow = LibDeployInit.initL1Contracts(
            _deployerOwnerAdmin,
            _l2NetworkId,
            _bridge,
            l1EscrowProxy,
            minterBurnerProxy,
            _l1Usdc
        );

        // init L2 contracts
        vm.selectFork(_l2Fork);
        (_minterBurner, _nativeConverter) = LibDeployInit.initL2Contracts(
            _deployerOwnerAdmin,
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

    function _deployMockBridge() internal {
        vm.selectFork(_l1Fork);
        MockBridge mb1 = new MockBridge();
        bytes memory mb1Code = address(mb1).code;
        vm.etch(_bridge, mb1Code);

        vm.selectFork(_l2Fork);
        MockBridge mb2 = new MockBridge();
        bytes memory mb2Code = address(mb2).code;
        vm.etch(_bridge, mb2Code);
    }

    function _toUSDC(uint256 v) internal pure returns (uint256) {
        return v * 10 ** 6;
    }
}
