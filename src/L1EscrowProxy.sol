// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract L1EscrowProxy is ERC1967Proxy {
    constructor(
        address impl_,
        bytes memory data_
    ) payable ERC1967Proxy(impl_, data_) {
        // set admin=deployer, this is changed on the subsequent call to init
        _changeAdmin(msg.sender);
    }
}
