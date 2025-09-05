// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/ERC7518.sol";
import "../src/CompliTo.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// Foundry test withr EIP-712 signature,
/// builds the calldata bytes ERC7518 expects,
/// then exercises mint and safeTransferFrom
contract ERC7518SignatureFlowTest is Test {
    ERC7518 token;
    CompliTo c;

    // signer for CompliTo validator role
    uint256 private validatorPk;
    address private validator;

    address admin = address(this);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address stablecoin = address(0x5555);

    // EIP-712 domain typehash
    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function setUp() public {
        validatorPk = 0xA11CE;
        validator = vm.addr(validatorPk);

        // deploy CompliTo with validator as DEFAULT_ADMIN_ROLE and VALIDATOR_ROLE
        c = new CompliTo(validator);

        // deploy upgradeable ERC7518 via proxy
        ERC7518 impl = new ERC7518();
        bytes memory initData = abi.encodeWithSelector(
            ERC7518.initialize.selector,
            "ipfs://base.json",
            address(c),
            address(0),
            stablecoin,
            admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        token = ERC7518(address(proxy));
    }

    // helper, compute CompliTo domain separator, matches EIP712("CompliTo","1.0.0")
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
    function _encodeSig(bytes32 r, bytes32 s, uint8 v, uint8 nonceType, bytes memory metadata)
        internal
        pure
        returns (bytes memory)
    {
        return bytes.concat(r, s, bytes1(v), bytes1(nonceType), metadata);
    }

    function _signSingle(
        address fromAddr,
        address toAddr,
        uint256 id,
        uint256 value,
        uint8 nonceType,
        uint256 nonce,
        bytes memory metadata
    ) internal view returns (bytes32 r, bytes32 s, uint8 v, bytes32 digest) {
        // struct hash for SetTransferApproval
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
        digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        (v, r, s) = vm.sign(validatorPk, digest);
    }

    function test_mint_and_transfer_with_real_signature() public {
        uint256 id = 1;
        uint256 mintAmount = 100;
        uint256 xferAmount = 40;

        // 1) Mint to Alice using nonceType = 1, global nonce = 0
        {
            uint8 nonceType = 1;
            uint256 nonce = 0; // global nonce initially 0
            bytes memory metadata = bytes("mint-meta");
            (bytes32 r, bytes32 s, uint8 v, ) = _signSingle(address(0), alice, id, mintAmount, nonceType, nonce, metadata);
            bytes memory data = _encodeSig(r, s, v, nonceType, metadata);

            // caller must have MINTER_ROLE, admin has it from constructor
            token.mint(alice, id, mintAmount, data);

            assertEq(token.balanceOf(alice, id), mintAmount, "minted balance mismatch");
        }

        // 2) Transfer from Alice to Bob using nonceType = 2, user nonce of Alice for this id, start at 0
        {
            uint8 nonceType = 2;
            uint256 nonce = 0; // per-user nonce starts at 0 for Alice,id
            bytes memory metadata = bytes("xfer-meta");
            (bytes32 r, bytes32 s, uint8 v, ) = _signSingle(alice, bob, id, xferAmount, nonceType, nonce, metadata);
            bytes memory data = _encodeSig(r, s, v, nonceType, metadata);

            // perform transfer as Alice
            vm.prank(alice);
            token.safeTransferFrom(alice, bob, id, xferAmount, data);

            assertEq(token.balanceOf(alice, id), 60, "alice balance mismatch");
            assertEq(token.balanceOf(bob, id),   40, "bob balance mismatch");
        }

        // 3) Reuse the same nonceType 2 signature should fail after nonce increments
        {
            uint8 nonceType = 2;
            uint256 nonce = 0; // same as before, should now be invalid
            bytes memory metadata = bytes("xfer-meta");
            (bytes32 r, bytes32 s, uint8 v, ) = _signSingle(alice, bob, id, 1, nonceType, nonce, metadata);
            bytes memory data = _encodeSig(r, s, v, nonceType, metadata);

            vm.prank(alice);
            vm.expectRevert(); // invalid signature due to nonce mismatch
            token.safeTransferFrom(alice, bob, id, 1, data);
        }
    }
}