// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ICompliTo} from "./interfaces/ICompliTo.sol";

/**
 * @title Compliance Contract for ERC-7518
 * @author Rajat K
 * @notice Provides signature-based transfer approvals using EIP-712
 */
contract CompliTo is EIP712, ICompliTo, AccessControl {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    bytes32 public constant EIP712_SET_TRANSFER_APPROVAL_TYPEHASH =
        keccak256(
            "SetTransferApproval(address from,address to,uint256 id,uint256 value,uint8 nonceType,uint256 nonce,bytes metadata)"
        );

    bytes32 public constant EIP712_SET_BATCH_TRANSFER_APPROVAL_TYPEHASH =
        keccak256(
            "SetBatchTransferApproval(address from,address to,uint256[] ids,uint256[] values,uint8 nonceType,uint256 nonce,bytes metadata)"
        );

    constructor(address admin) EIP712("CompliTo", "1.0.0") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VALIDATOR_ROLE, admin);
    }

    function _generateHashType(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        uint8 _nonceType,
        uint256 _nonce,
        bytes memory _metadata
    ) public view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    EIP712_SET_BATCH_TRANSFER_APPROVAL_TYPEHASH,
                    _from,
                    _to,
                    keccak256(abi.encodePacked(_ids)),
                    keccak256(abi.encodePacked(_values)),
                    _nonceType,
                    _nonce,
                    keccak256(_metadata)
                )
            )
        );
    }

    function _generateHashType(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        uint8 _nonceType,
        uint256 _nonce,
        bytes memory _metadata
    ) internal view returns (bytes32 digest) {
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    EIP712_SET_TRANSFER_APPROVAL_TYPEHASH,
                    _from,
                    _to,
                    _id,
                    _value,
                    _nonceType,
                    _nonce,
                    keccak256(_metadata)
                )
            )
        );
    }

    function getSigner(
        address from,
        address to,
        uint256 id,
        uint256 value,
        uint8 nonceType,
        uint256 nonce,
        bytes memory metadata,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external view returns (address) {
        bytes32 digest = _generateHashType(
            from,
            to,
            id,
            value,
            nonceType,
            nonce,
            metadata
        );
        return ECDSA.recover(digest, v, r, s);
    }

    function verifySignature(
        address from,
        address to,
        uint256 id,
        uint256 value,
        uint8 nonceType,
        uint256 nonce,
        bytes memory metadata,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool) {
        bytes32 digest = _generateHashType(
            from,
            to,
            id,
            value,
            nonceType,
            nonce,
            metadata
        );
        address recovered = ECDSA.recover(digest, v, r, s);
        return hasRole(VALIDATOR_ROLE, recovered);
    }

    function batchVerifySignature(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        uint8 nonceType,
        uint256 nonce,
        bytes memory metadata,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool) {
        bytes32 digest = _generateHashType(
            from,
            to,
            ids,
            values,
            nonceType,
            nonce,
            metadata
        );
        address recovered = ECDSA.recover(digest, v, r, s);
        return hasRole(VALIDATOR_ROLE, recovered);
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
