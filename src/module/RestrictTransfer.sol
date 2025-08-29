// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;
/**
 * @title Restrict transfer between addresses
 * @author Rajat K
 */

abstract contract RestrictTransfer {
    mapping(uint => bool) internal _restrictTransfer;

    event TransferRestricted(uint indexed id);
    event RestrictionRemoved(uint indexed id);

    error RestrictionStatusUnchanged();

    /**
     * @notice Checks if the specified ERC-1155 partition is transfer-restricted.
     * @dev Returns the transfer restriction status of the `id` partition.
     * @param id The ERC-1155 partition ID to check.
     * @return bool `true` if the partition is restricted, `false` otherwise.
     */
    function isRestricted(uint id) public view returns (bool) {
        return _restrictTransfer[id];
    }

    /**
     * @notice Applies a transfer restriction to the specified ERC-1155 partition.
     * @dev Sets the transfer restriction status of the `id` partition to `true` and emits a `TransferRestricted` event.
     * @param id The ERC-1155 partition ID to restrict.
     */
    function _restrict(uint id) internal {
        if (_restrictTransfer[id]) revert RestrictionStatusUnchanged();
        _restrictTransfer[id] = true;
        emit TransferRestricted(id);
    }

    /**
     * @notice Removes the transfer restriction from the specified ERC-1155 partition.
     * @param id The ERC-1155 partition ID to unrestrict.
     */
    function _removeRestriction(uint id) internal {
        if (!_restrictTransfer[id]) revert RestrictionStatusUnchanged();
        _restrictTransfer[id] = false;
        emit RestrictionRemoved(id);
    }

    uint256[50] private __gap;
}
