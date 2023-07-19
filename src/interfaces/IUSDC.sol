// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@oz/interfaces/IERC20.sol";

interface IUSDC is IERC20 {
    function burn(uint256 _amount) external;

    function mint(address _to, uint256 _amount) external returns (bool);
}
