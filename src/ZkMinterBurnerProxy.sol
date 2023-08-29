// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ZkMinterBurnerProxy is ERC1967Proxy {
    constructor(
        address impl,
        bytes memory data
    ) payable ERC1967Proxy(impl, data) {
        // set admin=deployer, this is changed on the subsequent call to init
        _changeAdmin(msg.sender);
    }
}
