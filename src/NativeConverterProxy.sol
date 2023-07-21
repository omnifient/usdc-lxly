// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@oz/proxy/ERC1967/ERC1967Proxy.sol";

contract NativeConverterProxy is ERC1967Proxy {
    constructor(
        address impl,
        bytes memory data
    ) payable ERC1967Proxy(impl, data) {}
}
