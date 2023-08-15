// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IUSDC is IERC20Upgradeable {
    function burn(uint256 _amount) external;

    function mint(address _to, uint256 _amount) external returns (bool);
}
