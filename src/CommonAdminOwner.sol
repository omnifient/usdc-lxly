// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract CommonAdminOwner is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    function __CommonAdminOwner_init() internal onlyInitializing {
        __Ownable_init(); // ATTN: this is overwritten by _transferOwnership
        __Pausable_init(); // NOOP
        __UUPSUpgradeable_init(); // NOOP
    }

    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "NOT_ADMIN");
        _;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyAdmin {
        // NOOP, we just need the onlyAdmin modifier to execute
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != _getAdmin(), "SAME_ADMIN");
        _changeAdmin(newAdmin);
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
