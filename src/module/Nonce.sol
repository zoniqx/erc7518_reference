// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

/**
 * @title Nonce Extension
 * @author Rajat K
 */

abstract contract Nonce {
    /* -------------------------------------------------------------------------- */
    /*                                Global nonce                                */
    /* -------------------------------------------------------------------------- */

    uint internal _globalNonces;

    event GlobalNonceIncreased(address indexed user, uint indexed nonce);

    function getGlobalNonce() public view returns (uint) {
        return _globalNonces;
    }

    function _increaseGlobalNonce(address account) internal {
        emit GlobalNonceIncreased(account, _globalNonces);
        _globalNonces++;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 User nonce                                 */
    /* -------------------------------------------------------------------------- */

    mapping(address => mapping(uint => uint)) internal _userNonces;

    event UserNonceIncreased(
        address indexed user,
        uint indexed id,
        uint indexed nonce
    );

    function getUserNonce(uint id) public view returns (uint) {
        return _userNonces[msg.sender][id];
    }

    function getUserNonceFor(address user, uint id) public view returns (uint) {
        return _userNonces[user][id];
    }

    function _increaseUserNonce(address account, uint id) internal {
        emit UserNonceIncreased(account, id, _userNonces[account][id]);
        _userNonces[account][id]++;
    }

    // function _getNonce(uint8 nonceType, uint id) internal returns (uint nonce) {
    //     if (nonceType == 1) {
    //         nonce = _globalNonces;
    //     } else if (nonceType == 2) {
    //         nonce = _userNonces[from][id];
    //     } else {
    //         revert("Invalid nonce type");
    //     }
    // }
}
