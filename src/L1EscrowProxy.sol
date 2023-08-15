// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@oz/proxy/ERC1967/ERC1967Proxy.sol";

contract L1EscrowProxy is ERC1967Proxy {
    constructor(
        address admin_,
        address impl_,
        bytes memory data_
    ) payable ERC1967Proxy(impl_, data_) {
        _changeAdmin(admin_);
    }
}
