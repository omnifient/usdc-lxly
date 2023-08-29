// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title LibPermit
/// @notice Library to call the EIP-2612 permit method on a token
library LibPermit {
    error NotValidSelector();
    error NotValidOwner();
    error NotValidSpender();
    error NotValidAmount();

    /// @dev bytes4(keccak256(bytes("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)")));
    bytes4 private constant _PERMIT_SIGNATURE = 0xd505accf;

    /// @notice Function to call token the EIP-2612 permit method on a token
    /// @dev Adapted from PolygonZKEVMBridge.sol's `_permit`
    /// @param token ERC20 token address
    /// @param amount Quantity that is expected to be allowed
    /// @param permitData Raw data of the call `permit` of the token
    function permit(
        address token,
        uint256 amount,
        bytes calldata permitData
    ) internal {
        if (bytes4(permitData[:4]) != _PERMIT_SIGNATURE)
            revert NotValidSelector();

        (
            address owner,
            address spender,
            uint256 value,
            uint256 deadline,
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = abi.decode(
                permitData[4:],
                (address, address, uint256, uint256, uint8, bytes32, bytes32)
            );

        if (owner != msg.sender) {
            revert NotValidOwner();
        }
        if (spender != address(this)) {
            revert NotValidSpender();
        }

        if (value != amount) {
            revert NotValidAmount();
        }

        // we call without checking the result, in case it fails and they don't have enough balance
        // the following transferFrom should be fail. This prevents DoS attacks from using a signature
        // before the smartcontract call
        /* solhint-disable avoid-low-level-calls */
        address(token).call(
            abi.encodeWithSelector(
                _PERMIT_SIGNATURE,
                owner,
                spender,
                value,
                deadline,
                v,
                r,
                s
            )
        );
    }
}
