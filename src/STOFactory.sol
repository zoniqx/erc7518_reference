// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

/**
 * @title Compliance Contract for ERC 7518 Protocol token.
 * @author Rajat K
 */

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1155Mod} from "./ERC1155Mod.sol";

contract STOFactory is UUPSUpgradeable, AccessControlUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    mapping(string => address) public StoIdMap;

    function initialize() public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    event STOCreated(
        address indexed stoAddress,
        uint tokenForSale,
        uint tokenPrice,
        address indexed tokenAddress
    );

    function createSTO(
        uint256 _tokensForSale,
        uint256 _tokenPrice,
        address stableCoin,
        address _tokenContractAddress,
        address _forwarderAddress,
        string memory id,
        string memory domainName,
        string memory signatureVersion
    ) public returns (address) {
        ERC1155Mod sto = new ERC1155Mod(
            _tokensForSale,
            _tokenPrice,
            stableCoin,
            _tokenContractAddress,
            _forwarderAddress,
            _msgSender(),
            domainName,
            signatureVersion
        );
        emit STOCreated(
            address(sto),
            _tokensForSale,
            _tokenPrice,
            _tokenContractAddress
        );

        StoIdMap[id] = address(sto);
        return address(sto);
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
