// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "lib/zkevm-contracts/contracts/interfaces/IBridgeMessageReceiver.sol";
import "lib/zkevm-contracts/contracts/lib/TokenWrapped.sol";
import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Vm.sol";

struct BridgeMessage {
    uint32 originNetwork;
    address originAddress;
    uint32 destinationNetwork;
    address destinationAddress;
    uint256 amount;
    bytes metadata;
}

/// @title A copy of PolygonZKEVMBridge to be used in invariant tests.
/// @notice The code is a stripped down version of PolygonZKEVMBridge.sol with only
/// the functions that we care about.
contract InvMockBridge {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Wrapped Token information struct
    struct TokenInformation {
        uint32 originNetwork;
        address originTokenAddress;
    }

    // Merkle tree levels
    uint256 internal constant _DEPOSIT_CONTRACT_TREE_DEPTH = 32;

    // Mainnet identifier
    uint32 private constant _MAINNET_NETWORK_ID = 0;

    // Number of networks supported by the bridge
    uint32 private constant _CURRENT_SUPPORTED_NETWORKS = 2;

    // Leaf type asset
    uint8 private constant _LEAF_TYPE_ASSET = 0;

    // Leaf type message
    uint8 private constant _LEAF_TYPE_MESSAGE = 1;

    // Network identifier
    uint32 public networkID;

    // Wrapped token Address --> Origin token information
    mapping(address => TokenInformation) public wrappedTokenToTokenInfo;

    uint32 public depositCount;
    BridgeMessage public lastBridgeMessage;

    Vm internal vm;
    address internal realBridge;

    constructor(Vm _vm, address _realBridge) {
        vm = _vm;
        realBridge = _realBridge;

        if (vm.activeFork() == 0) {
            // L1 (mainnet)
            networkID = 0;
        } else if (vm.activeFork() == 1) {
            // L2 (zkevm)
            networkID = 1;

            address token = 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035;
            wrappedTokenToTokenInfo[token] = InvMockBridge.TokenInformation({
                originNetwork: 0,
                originTokenAddress: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
            });
        }
    }

    // function initialize(
    //     uint32 _networkID,
    //     Vm _vm,
    //     address _realBridge,
    //     address _token,
    //     uint32 _originNetwork,
    //     address _originTokenAddr
    // ) external virtual {
    //     networkID = _networkID;
    //     vm = _vm;
    //     realBridge = _realBridge;

    //     if (_token != address(0)) {
    //         wrappedTokenToTokenInfo[_token] = InvMockBridge.TokenInformation({
    //             originNetwork: _originNetwork,
    //             originTokenAddress: _originTokenAddr
    //         });
    //     }
    // }

    /**
     * @dev Emitted when bridge assets or messages to another network
     */
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

    /**
     * @dev Emitted when a claim is done from another network
     */
    event ClaimEvent(
        uint32 index,
        uint32 originNetwork,
        address originAddress,
        address destinationAddress,
        uint256 amount
    );

    /**
     * @notice Deposit add a new leaf to the merkle tree
     * @param destinationNetwork Network destination
     * @param destinationAddress Address destination
     * @param amount Amount of tokens
     * @param token Token address, 0 address is reserved for ether
     * @param forceUpdateGlobalExitRoot Indicates if the new global exit root is updated or not
     * @param permitData Raw data of the call `permit` of the token
     */
    function bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        address token,
        bool forceUpdateGlobalExitRoot,
        bytes calldata permitData
    ) public payable virtual {
        address originTokenAddress;
        uint32 originNetwork;
        bytes memory metadata;
        uint256 leafAmount = amount;

        if (token != address(0)) {
            // Check msg.value is 0 if tokens are bridged
            require(msg.value == 0, "MSG_VALUE_NOT_ZERO");

            TokenInformation memory tokenInfo = wrappedTokenToTokenInfo[token];
            console.log("yyyyyyy fork", vm.activeFork());
            console.log("xxxxxxx token", token);
            console.log(
                "xxxxxxx tokenInfo origin token addr",
                tokenInfo.originTokenAddress
            );
            console.log(
                "xxxxxxx tokenInfo origin network",
                tokenInfo.originNetwork
            );
            if (tokenInfo.originTokenAddress != address(0)) {
                // The token is a wrapped token from another network

                // Burn tokens
                if (realBridge != address(0)) {
                    address currentSender = msg.sender;
                    // changePrank(realBridge);
                    vm.stopPrank();
                    vm.startPrank(realBridge);
                    console.log("swapping pranks", currentSender, realBridge);
                    TokenWrapped(token).burn(msg.sender, amount);
                    // changePrank(currentSender);
                    vm.stopPrank();
                    vm.startPrank(currentSender);
                }

                originTokenAddress = tokenInfo.originTokenAddress;
                originNetwork = tokenInfo.originNetwork;
            }
        }

        emit BridgeEvent(
            _LEAF_TYPE_ASSET,
            originNetwork,
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // originTokenAddress,
            destinationNetwork,
            destinationAddress,
            leafAmount,
            metadata,
            uint32(depositCount)
        );

        lastBridgeMessage = BridgeMessage(
            originNetwork,
            originTokenAddress,
            destinationNetwork,
            destinationAddress,
            amount,
            metadata
        );
    }

    /**
     * @notice Bridge message and send ETH value
     * @param destinationNetwork Network destination
     * @param destinationAddress Address destination
     * @param forceUpdateGlobalExitRoot Indicates if the new global exit root is updated or not
     * @param metadata Message metadata
     */
    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool forceUpdateGlobalExitRoot,
        bytes calldata metadata
    ) external payable {
        emit BridgeEvent(
            _LEAF_TYPE_MESSAGE,
            networkID,
            msg.sender,
            destinationNetwork,
            destinationAddress,
            msg.value,
            metadata,
            uint32(depositCount)
        );

        lastBridgeMessage = BridgeMessage(
            networkID,
            msg.sender,
            destinationNetwork,
            destinationAddress,
            msg.value,
            metadata
        );
    }

    /**
     * @notice Verify merkle proof and withdraw tokens/ether
     * @param smtProof Smt proof
     * @param index Index of the leaf
     * @param mainnetExitRoot Mainnet exit root
     * @param rollupExitRoot Rollup exit root
     * @param originNetwork Origin network
     * @param originTokenAddress  Origin token address, 0 address is reserved for ether
     * @param destinationNetwork Network destination
     * @param destinationAddress Address destination
     * @param amount Amount of tokens
     * @param metadata Abi encoded metadata if any, empty otherwise
     */
    function claimAsset(
        bytes32[_DEPOSIT_CONTRACT_TREE_DEPTH] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originTokenAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external {
        // Transfer funds
        if (originTokenAddress != address(0)) {
            // Transfer tokens
            if (originNetwork == networkID) {
                // The token is an ERC20 from this network
                IERC20Upgradeable(originTokenAddress).safeTransfer(
                    destinationAddress,
                    amount
                );
            }
        }

        emit ClaimEvent(
            index,
            originNetwork,
            originTokenAddress,
            destinationAddress,
            amount
        );
    }

    /**
     * @notice Verify merkle proof and execute message
     * If the receiving address is an EOA, the call will result as a success
     * Which means that the amount of ether will be transferred correctly, but the message
     * will not trigger any execution
     * @param smtProof Smt proof
     * @param index Index of the leaf
     * @param mainnetExitRoot Mainnet exit root
     * @param rollupExitRoot Rollup exit root
     * @param originNetwork Origin network
     * @param originAddress Origin address
     * @param destinationNetwork Network destination
     * @param destinationAddress Address destination
     * @param amount message value
     * @param metadata Abi encoded metadata if any, empty otherwise
     */
    function claimMessage(
        bytes32[_DEPOSIT_CONTRACT_TREE_DEPTH] calldata smtProof,
        uint32 index,
        bytes32 mainnetExitRoot,
        bytes32 rollupExitRoot,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        bytes calldata metadata
    ) external {
        // Execute message
        // Transfer ether
        /* solhint-disable avoid-low-level-calls */
        (bool success, ) = destinationAddress.call{value: amount}(
            abi.encodeCall(
                IBridgeMessageReceiver.onMessageReceived,
                (originAddress, originNetwork, metadata)
            )
        );
        require(success, "MESSAGE_FAILED");

        emit ClaimEvent(
            index,
            originNetwork,
            originAddress,
            destinationAddress,
            amount
        );
    }
}
