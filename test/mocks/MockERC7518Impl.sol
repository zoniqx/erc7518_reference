// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

contract MockERC7518Impl {
    bool public initialized;
    string public lastUri;
    address public lastCompliance;
    address public lastForwarder;
    address public lastPayout;
    address public lastOwner;

    event Initialized(string uri, address compliance, address forwarder, address payout, address owner);

    function initialize(
        string calldata uri,
        address compliance,
        address forwarder,
        address payout,
        address owner
    ) external {
        require(!initialized, "already initialized");
        initialized = true;
        lastUri = uri;
        lastCompliance = compliance;
        lastForwarder = forwarder;
        lastPayout = payout;
        lastOwner = owner;
        emit Initialized(uri, compliance, forwarder, payout, owner);
    }
}