// SPDX-License-Identifier: GPL-3.0


/**
 * @title  ERC1155 allowance wrapper
 * @author Rajat K
 */

pragma solidity ^0.8.9;

abstract contract ERC1155AllowanceWrapper {
    // from => operator => id => allowance
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        internal _allowances;

    error ERC1155ZeroApproveAddress(address account);
    error ERC1155InsufficientAllowance(uint given, uint have);
    /**
        @dev MUST emit on any successful call to approve(address _spender, uint256 _id, uint256 _currentValue, uint256 _value)
    */
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 indexed _id,
        uint256 _value
    );

    /**
        @notice Allow other accounts/contracts to spend tokens on behalf of msg.sender
        @dev MUST emit Approval event on success.
        To minimize the risk of the approve/transferFrom attack vector (see https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/), this function will throw if the current approved allowance does not equal the expected _currentValue, unless _value is 0.
        @param spender      Address to approve
        @param id           ID of the Token
        @param value        Allowance amount
    */
    function _approve(
        address owner,
        address spender,
        uint256 id,
        uint256 value
    ) internal virtual {
        if (owner == address(0)) revert ERC1155ZeroApproveAddress(owner);
        if (spender == address(0)) revert ERC1155ZeroApproveAddress(spender);
        _allowances[owner][spender][id] = value;
        emit Approval(owner, spender, id, value);
    }

    /**
        @notice Queries the spending limit approved for an account
        @param owner    The owner allowing the spending
        @param spender  The address allowed to spend.
        @param id       ID of the Token
        @return          The _spender's allowed spending balance of the Token requested
     */
    function allowance(
        address owner,
        address spender,
        uint256 id
    ) public view returns (uint256) {
        return _allowances[owner][spender][id];
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount,
        uint256 id
    ) internal virtual returns (bool) {
        uint256 currentAllowance = allowance(owner, spender, id);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount)
                revert ERC1155InsufficientAllowance(amount, currentAllowance);
            unchecked {
                _approve(owner, spender, currentAllowance - amount, id);
            }
            return true;
        }
        return false;
    }

    uint256[50] private __gap;
}
