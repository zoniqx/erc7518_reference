// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

/**
 * @title Freeze Address Extension
 * @author Rajat Kumar
 */
abstract contract IssuerFactory {
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event DealInstantiation(
        address indexed issuer,
        address indexed instantiation,
        string _dealId
    );
    event AddedToWhitelist(address indexed user);
    event RemovedFromWhiteList(address indexed user);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    mapping(address => bool) public isInstantiation;
    mapping(address => address[]) public instantiations;
    mapping(address => address) public dealIssuer;
    mapping(string => address) public dealIdToAddress;

    mapping(address => bool) public whiteListUsers;

    /* -------------------------------------------------------------------------- */
    /*                                  Modifiers                                 */
    /* -------------------------------------------------------------------------- */
    modifier onlyWhiteListed() {
        require(whiteListUsers[msg.sender], "Only whitelist");
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Function                             */
    /* -------------------------------------------------------------------------- */

    function _addToWhitelist(address user) internal {
        whiteListUsers[user] = true;
        emit AddedToWhitelist(user);
    }

    /**
     * @dev remove user from whitelist
     */
    function _removeFromWhiteList(address user) internal {
        require(whiteListUsers[user], "User is not in the whitelist");
        whiteListUsers[user] = false;
        emit RemovedFromWhiteList(user);
    }

    /**
     * @dev Registers contract in issuer registry.
     * @param instantiation Address of contract instantiation.
     * @param _dealId Id of the deal or asset.
     */
    function _register(address instantiation, string memory _dealId) internal {
        isInstantiation[instantiation] = true;
        instantiations[msg.sender].push(instantiation);
        dealIssuer[instantiation] = msg.sender;
        dealIdToAddress[_dealId] = instantiation;
        emit DealInstantiation(msg.sender, instantiation, _dealId);
    }

    /* -------------------------------------------------------------------------- */
    /*                              External Function                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev returns number of deals by issuer.
     * @param issuer Contract issuer.
     * @return deals number of deals by issuer.
     */
    function getDealsCount(
        address issuer
    ) external view returns (uint256 deals) {
        return instantiations[issuer].length;
    }

    uint256[50] private __gap;
}
