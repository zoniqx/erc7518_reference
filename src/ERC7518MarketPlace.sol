// SPDX-License-Identifier: GPL-3.0

/**
 * @title Factor Contract to deploy ERC 7518
 * @author Rajat K, Rajat
 */
pragma solidity 0.8.15;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IMarketplace} from "./interfaces/IMarketPlace.sol";
import {ERC7518} from "./ERC7518.sol";
import {IssuerFactory} from "./module/IssuerFactory.sol";

/// @title Marketplace - Allows creation and listing of custom deal tokens.
contract ERC7518Marketplace is
    IMarketplace,
    IssuerFactory,
    Ownable,
    ReentrancyGuard
{
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */
    event ForwarderAddressChanged(
        address indexed oldForwarder,
        address indexed newForwarder
    );
    event ComplianceAddressChanged(
        address indexed oldCompliance,
        address indexed newCompliance
    );
    event PayoutAddressChanged(
        address indexed oldPayout,
        address indexed newPayout
    );
    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    address internal _forwarder;
    address internal _compliance;
    address internal _payout;

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */

    constructor(
        address forwarder,
        address compliance,
        address payout
    ) {
        require(
            compliance != address(0) &&
                forwarder != address(0) &&
                payout != address(0),
            "Zero address"
        );
        _forwarder = forwarder;
        _compliance = compliance;
        _payout = payout;
    }

    /* -------------------------------------------------------------------------- */
    /*                              External Function                             */
    /* -------------------------------------------------------------------------- */

    function complianceAddress() external view returns (address) {
        return _compliance;
    }

    function forwarderAddress() external view returns (address) {
        return _forwarder;
    }

    function payoutAddress() external view returns (address) {
        return _payout;
    }


    /**
     * @dev Change the forwarder address.
     * @param forwarder The new forwarder address.
     */
    function changeForwarderAddress(
        address forwarder
    ) external virtual onlyOwner {
        require(forwarder != address(0), "Zero address");
        _forwarder = forwarder;
        emit ForwarderAddressChanged(_forwarder, forwarder);
    }


    /**
     * @dev Change the payout address.
     * @param payout new payout address.
     */
    function changePayoutAddress(address payout) external virtual onlyOwner {
        require(payout != address(0), "Zero address");
        _payout = payout;
        emit PayoutAddressChanged(address(_payout), address(payout));
    }

    /**
     * @dev Change the compliance address.
     * @param compliance The new compliance address.
     */
    function changeComplianceAddress(
        address compliance
    ) external virtual onlyOwner {
        require(compliance != address(0), "Zero address");
        _compliance = compliance;
        emit ComplianceAddressChanged(address(_compliance), address(compliance));
    }

    /**
        @param user address to be whitelisted
     */
    function whitelist(address user) external onlyOwner {
        require(!whiteListUsers[user], "MarketPlace: User already whiteListed");
        _addToWhitelist(user);
    }

    /**
     *  @notice Remove user from whitelist
     *  @param user address to be remove from whitelist
     */
    function removeWhiteList(address user) external onlyOwner {
        _removeFromWhiteList(user);
    }

    /**
     * @notice deploy ERC 7518
     * @param uri for deal
     * @param dealId  ID of the Token
     * @return  depoyed contract address.
     */
    function create(
        string memory uri,
        string memory dealId
    ) external onlyWhiteListed nonReentrant returns (address) {
        require(dealIdToAddress[dealId] == address(0x0), "Duplicate dealId");
        ERC7518 newContract = new ERC7518(
            uri,
            _compliance,
            _forwarder,
            _payout,
            _msgSender()
        );
        _register(address(newContract), dealId);
        return address(newContract);
    }


    function version() public pure virtual returns (string memory) {
        return "2.2.0";
    }

}
