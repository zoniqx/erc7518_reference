// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

/**
 * @title Freeze Address Extension
 * @author Rajat K
 */

abstract contract FreezeAddress {
    mapping(address => bool) public frozen;

    event Frozen(address indexed account);
    event Unfrozen(address indexed account);

    error FrozenAddress(address account);
    error AccountAlreadyFrozen(address account);
    error AccountNotFrozen(address account);

    /**
     * @notice Freezes the specified address.
     * @dev Sets the `frozen` status of the `account` to `true` and emits a `Frozen` event.
     * @param account The address to freeze.
     */
    function _freeze(address account) internal {
        if (frozen[account]) {
            revert AccountAlreadyFrozen(account);
        }
        frozen[account] = true;
        emit Frozen(account);
    }

    /**
     * @notice Unfreezes the specified address.
     * @dev Sets the `frozen` status of the `account` to `false` and emits an `Unfrozen` event.
     * @param account The address to unfreeze.
     */

    function _unfreeze(address account) internal {
       if (!frozen[account]) {
            revert AccountNotFrozen(account);
        }
        frozen[account] = false;
        emit Unfrozen(account);
    }

    function isFrozen(address account) public view returns (bool) {
        return frozen[account];
    }

    function _checkFreezeAddress(address account) internal view {
        if (isFrozen(account)) revert FrozenAddress(account);
    }

    uint256[50] private __gap;
}
