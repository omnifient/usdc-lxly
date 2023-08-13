// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library LibPermit {
    error NotValidSelector();
    error NotValidOwner();
    error NotValidSpender();
    error NotValidAmount();

    // bytes4(keccak256(bytes("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)")));
    bytes4 private constant _PERMIT_SIGNATURE = 0xd505accf;

    /// @dev Adapted from PolygonZKEVMBridge.sol's `_permit`
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
