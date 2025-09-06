// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/CompliTo.sol";

contract CompliToTest is Test {
    CompliTo public c;
    uint256 private validatorPk;
    address private validator;

    bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    function setUp() public {
        validatorPk = 0xA11CE;
        validator = vm.addr(validatorPk);
        c = new CompliTo(validator);
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("CompliTo")),
                keccak256(bytes("1.0.0")),
                block.chainid,
                address(c)
            )
        );
    }

    function test_verifySignature_single() public {
        address fromAddr = address(0);
        address toAddr = address(0xB0B);
        uint256 id = 1;
        uint256 value = 50;
        uint8 nonceType = 1;
        uint256 nonce = 0;
        bytes memory metadata = bytes("hello");

        bytes32 typehash = c.EIP712_SET_TRANSFER_APPROVAL_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(
                typehash,
                fromAddr,
                toAddr,
                id,
                value,
                nonceType,
                nonce,
                keccak256(metadata)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPk, digest);

        bool ok = c.verifySignature(fromAddr, toAddr, id, value, nonceType, nonce, metadata, v, r, s);
        assertTrue(ok, "single verifySignature should pass for validator signer");

        address rec = c.getSigner(fromAddr, toAddr, id, value, nonceType, nonce, metadata, r, s, v);
        assertEq(rec, validator, "recovered signer must be validator");
    }

    function test_verifySignature_batch() public {
        address fromAddr = address(0x1111);
        address toAddr = address(0x2222);
        uint256[] memory ids = new uint256[](3);
        uint256[] memory values = new uint256[](3);
        ids[0] = 7; ids[1] = 8; ids[2] = 9;
        values[0] = 10; values[1] = 20; values[2] = 30;

        uint8 nonceType = 1;
        uint256 nonce = 123456;
        bytes memory metadata = abi.encode(uint256(42));

        bytes32 typehash = c.EIP712_SET_BATCH_TRANSFER_APPROVAL_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(
                typehash,
                fromAddr,
                toAddr,
                keccak256(abi.encodePacked(ids)),
                keccak256(abi.encodePacked(values)),
                nonceType,
                nonce,
                keccak256(metadata)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPk, digest);

        bool ok = c.batchVerifySignature(fromAddr, toAddr, ids, values, nonceType, nonce, metadata, v, r, s);
        assertTrue(ok, "batch verifySignature should pass for validator signer");
    }
}