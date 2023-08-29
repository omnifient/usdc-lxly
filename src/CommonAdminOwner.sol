// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title CommonAdminOwner
/// @notice An upgradeable contract that, when inherited from, provides 4 functionalities:
/// 1. The ability to pause and unpause functions with the `whenNotPaused` modifier
/// 2. The ability to transfer ownership (which controls who can pause/unpause)
/// 3. UUPS upgradeability, and the admin role which is allowed to upgrade
/// the implementation contract
/// 4. The ability to change the admin (which controls upgradeability)
contract CommonAdminOwner is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    /// @notice The initializer, which must be used instead of the constructor
    /// @notice because this is a UUPS contract
    function __CommonAdminOwner_init() internal onlyInitializing {
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
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
