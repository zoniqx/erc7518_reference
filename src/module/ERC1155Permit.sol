// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

/**
 * @title Permit for ERC-1155
 * @author Rajat K
 */

abstract contract ERC1155Permit {
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 id,uint256 value,uint256 nonce,uint256 deadline)"
        );
    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);
    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    mapping(address => mapping(uint => uint256)) private _permitNonces;

    event PermitNonceUsed(
        address indexed account,
        uint indexed id,
        uint256 indexed nonce
    );

    /**
     * @notice Uses the current permit nonce for a given account and id, then increments it.
     * @dev This function is internal and updates the permit nonce for the given account and id.
     * @param account The address of the account whose permit nonce is being used.
     * @param id The ERC-1155 token ID for which the permit nonce is being used.
     */ function _usePermitNonce(
        address account,
        uint256 id
    ) internal returns (uint256 current) {
        current = _permitNonces[account][id];
        _permitNonces[account][id] = current + 1;
        emit PermitNonceUsed(account, id, current);
    }

    function getPermitNonce(
        address account,
        uint256 id
    ) public view returns (uint256) {
        return _permitNonces[account][id];
    }

    function permit(
        address owner,
        address spender,
        uint256 id,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual;
}
