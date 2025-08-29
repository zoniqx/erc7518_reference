// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

interface IMarketplace {
    function changeComplianceAddress(address compliance) external;

    function changePayoutAddress(address payout) external;

    function changeForwarderAddress(address forwarder) external;

    function whitelist(address user) external;

    function removeWhiteList(address user) external;

    function create(
        string memory uri,
        string memory dealId
    ) external returns (address);
}
