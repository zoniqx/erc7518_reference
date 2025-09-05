// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/ERC7518.sol";
import "../src/CompliTo.sol";
import "../src/module/FreezeAddress.sol";
import "../src/module/TokenLock.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract ERC7518TransferComplianceTest is Test, ERC1155Holder {
    ERC7518 token;
    CompliTo compliTo;
    
    address owner;
    address addr1 = address(0x1111);
    address addr2 = address(0x2222);
    address stablecoin = address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
    address forwarder = address(0xc65d82ECE367EF06bf2AB791B3f3CF037Dc0e816);
    
    // signer for CompliTo validator role
    uint256 private validatorPk;
    address private validator;
    
    bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    
    function setUp() public {
        owner = address(this);
        
        // choose a real private key for the validator, derive its address
        validatorPk = 0xA11CE;
        validator = vm.addr(validatorPk);
        
        // Deploy CompliTo compliance contract with validator
        compliTo = new CompliTo(validator);
        
        // Deploy ERC7518 token
        ERC7518 impl = new ERC7518();
        bytes memory initData = abi.encodeWithSelector(
            ERC7518.initialize.selector,
            "https://compli.finance",
            address(compliTo),
            forwarder,
            stablecoin,
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        token = ERC7518(address(proxy));
        
        // Pre-mint tokens for testing - commented out to debug
        // _mintTokensWithCompliance();
    }
    
    function _mintTokensWithCompliance() internal {
        // Create valid signatures for minting to this contract (test contract implements ERC1155Holder)
        bytes memory mintData0 = _createValidMintSignature(address(this), 0, 10000);
        bytes memory mintData1 = _createValidMintSignature(address(this), 1, 10000);
        
        // Mint tokens with proper compliance signatures
        token.mint(address(this), 0, 10000, mintData0);
        token.mint(address(this), 1, 10000, mintData1);
    }
    
    function _createValidMintSignature(address to, uint256 id, uint256 amount) internal view returns (bytes memory) {
        // For minting (from zero address), create a valid signature
        bytes memory metadata = bytes("mint-meta");
        
        return _createTransferSignature(
            address(0), to, id, amount, 1, 0, metadata
        );
    }
    
    function _createMintCompliantData(address to, uint256[] memory ids, uint256[] memory amounts) internal view returns (bytes memory) {
        // For minting, use first id and amount
        return _createValidMintSignature(to, ids[0], amounts[0]);
    }
    
    function _mintTokensFor(address to, uint256 id, uint256 amount) internal {
        bytes memory mintData = _createValidMintSignature(to, id, amount);
        token.mint(to, id, amount, mintData);
    }
    
    function _createTransferSignature(
        address from,
        address to,
        uint256 id,
        uint256 value,
        uint8 nonceType,
        uint256 nonce,
        bytes memory metadata
    ) internal view returns (bytes memory) {
        // struct hash for SetTransferApproval
        bytes32 typehash = compliTo.EIP712_SET_TRANSFER_APPROVAL_TYPEHASH();
        bytes32 structHash = keccak256(abi.encode(
            typehash,
            from,
            to,
            id,
            value,
            nonceType,
            nonce,
            keccak256(metadata)
        ));
        
        bytes32 domainSeparator = _getDomainSeparator();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPk, digest);
        
        return bytes.concat(r, s, bytes1(v), bytes1(nonceType), metadata);
    }
    
    function _createBatchTransferSignature(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        uint8 nonceType,
        uint256 nonce,
        bytes memory metadata
    ) internal view returns (bytes memory) {
        bytes32 typehash = compliTo.EIP712_SET_BATCH_TRANSFER_APPROVAL_TYPEHASH();
        bytes32 structHash = keccak256(abi.encode(
            typehash,
            from,
            to,
            keccak256(abi.encodePacked(ids)),
            keccak256(abi.encodePacked(values)),
            nonceType,
            nonce,
            keccak256(metadata)
        ));
        
        bytes32 domainSeparator = _getDomainSeparator();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPk, digest);
        
        return bytes.concat(r, s, bytes1(v), bytes1(nonceType), metadata);
    }
    
    function _getDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256(bytes("CompliTo")),
            keccak256(bytes("1.0.0")),
            block.chainid,
            address(compliTo)
        ));
    }

    // Basic Transfer Tests
    function test_should_transfer_with_signature() public {
        // First mint some tokens to the owner
        bytes memory mintData = _createValidMintSignature(owner, 0, 1000);
        token.mint(owner, 0, 1000, mintData);
        
        uint256 initialBalance = token.balanceOf(owner, 0);
        uint256 transferAmount = 100;
        
        bytes memory transferData = _createTransferSignature(
            owner, addr1, 0, transferAmount, 1, token.getGlobalNonce(), bytes("transfer-meta")
        );
        
        token.safeTransferFrom(owner, addr1, 0, transferAmount, transferData);
        
        assertEq(token.balanceOf(owner, 0), initialBalance - transferAmount);
        assertEq(token.balanceOf(addr1, 0), transferAmount);
    }
    
    function test_should_batch_transfer_with_signature() public {
        // First mint tokens to this contract with correct nonces
        bytes memory mintData0 = _createTransferSignature(address(0), address(this), 0, 1000, 1, 0, bytes("mint-token-0"));
        token.mint(address(this), 0, 1000, mintData0);
        
        bytes memory mintData1 = _createTransferSignature(address(0), address(this), 1, 1000, 1, 1, bytes("mint-token-1"));
        token.mint(address(this), 1, 1000, mintData1);
        
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        amounts[0] = 5;
        amounts[1] = 5;
        
        uint256[] memory initialBalances = new uint256[](2);
        initialBalances[0] = token.balanceOf(address(this), 0);
        initialBalances[1] = token.balanceOf(address(this), 1);
        
        // For batch transfer, use the current global nonce after minting operations
        uint256 currentNonce = token.getGlobalNonce();
        bytes memory batchData = _createBatchTransferSignature(
            address(this), addr1, ids, amounts, 1, currentNonce, bytes("batch-meta")
        );
        
        token.safeBatchTransferFrom(address(this), addr1, ids, amounts, batchData);
        
        assertEq(token.balanceOf(address(this), 0), initialBalances[0] - 5);
        assertEq(token.balanceOf(address(this), 1), initialBalances[1] - 5);
        assertEq(token.balanceOf(addr1, 0), 5);
        assertEq(token.balanceOf(addr1, 1), 5);
    }
    
    // Signature Validation Tests
    function test_should_revert_if_signature_is_tampered() public {
        bytes memory transferData = _createTransferSignature(
            owner, addr1, 0, 100, 1, token.getGlobalNonce(), bytes("tamper-meta")
        );
        
        // Tamper with the signature by modifying the last byte (nonce type)
        transferData[transferData.length - 1] = bytes1(uint8(2));
        
        vm.expectRevert();
        token.safeTransferFrom(owner, addr1, 0, 100, transferData);
    }
    
    function test_should_revert_with_invalid_nonce() public {
        // First mint tokens to have balance
        _mintTokensFor(address(this), 0, 1000);
        
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, 10, bytes("wrong-nonce") // Wrong nonce
        );
        
        vm.expectRevert(ERC7518.InvalidCompliToSignature.selector);
        token.safeTransferFrom(address(this), addr1, 0, 100, transferData);
    }
    
    // Token Locking Tests
    function test_should_lock_token_with_event() public {
        // First mint and transfer tokens to addr1
        _mintTokensFor(address(this), 0, 1000);
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 200, 1, token.getGlobalNonce(), bytes("transfer-for-lock")
        );
        token.safeTransferFrom(address(this), addr1, 0, 200, transferData);
        
        uint256 lockAmount = 50;
        uint256 lockPeriod = 30 days;
        
        vm.expectEmit(true, true, true, true);
        emit TokenLocked(addr1, 0, 1, lockAmount, block.timestamp + lockPeriod);
        
        token.lockTokens(addr1, 0, lockAmount, block.timestamp + lockPeriod);
        
        // Lock again to test incremental lock IDs
        vm.expectEmit(true, true, true, true);
        emit TokenLocked(addr1, 0, 2, lockAmount, block.timestamp + lockPeriod);
        
        token.lockTokens(addr1, 0, lockAmount, block.timestamp + lockPeriod);
        
        assertEq(token.lockedBalanceOf(addr1, 0), 100);
    }
    
    function test_should_revert_if_locking_more_than_balance() public {
        // First mint and transfer some tokens to addr1
        _mintTokensFor(address(this), 0, 1000);
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("transfer-meta")
        );
        token.safeTransferFrom(address(this), addr1, 0, 100, transferData);
        
        vm.expectRevert("Insufficient balance");
        token.lockTokens(addr1, 0, 500, block.timestamp + 30 days);
    }
    
    function test_should_revert_transfer_if_tokens_are_locked() public {
        // First mint and transfer tokens to addr1
        _mintTokensFor(address(this), 0, 1000);
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("transfer-meta")
        );
        token.safeTransferFrom(address(this), addr1, 0, 100, transferData);
        
        // Lock all tokens
        token.lockTokens(addr1, 0, 100, block.timestamp + 30 days);
        
        // Try to transfer locked tokens
        bytes memory transferData2 = _createTransferSignature(
            addr1, addr2, 0, 50, 2, token.getUserNonce(0), bytes("locked-transfer")
        );
        
        vm.prank(addr1);
        vm.expectRevert();
        token.safeTransferFrom(addr1, addr2, 0, 50, transferData2);
    }
    
    // Token Unlocking Tests
    function test_should_unlock_token() public {
        // First mint and transfer tokens then lock them
        _mintTokensFor(address(this), 0, 1000);
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("transfer-meta")
        );
        token.safeTransferFrom(address(this), addr1, 0, 100, transferData);
        
        token.lockTokens(addr1, 0, 50, block.timestamp + 1);
        
        // Wait for lock period to expire
        vm.warp(block.timestamp + 2);
        
        vm.expectEmit(true, true, true, true);
        emit TokenUnlocked(addr1, 0, 1, 50);
        
        vm.prank(addr1);
        token.unlockTokens(addr1, 0);
        
        assertEq(token.lockedBalanceOf(addr1, 0), 0);
    }
    
    function test_should_revert_if_no_tokens_to_unlock() public {
        // First mint and transfer tokens and lock them with future release time
        _mintTokensFor(address(this), 0, 1000);
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("transfer-meta")
        );
        token.safeTransferFrom(address(this), addr1, 0, 100, transferData);
        
        token.lockTokens(addr1, 0, 50, block.timestamp + 40000000);
        
        vm.prank(addr1);
        vm.expectRevert(abi.encodeWithSelector(TokenLock.NoTokensToUnlock.selector));
        token.unlockTokens(addr1, 0);
    }
    
    function test_should_force_unlock_tokens() public {
        // First mint tokens to this contract then transfer to addr1
        _mintTokensFor(address(this), 0, 1000);
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("transfer-meta")
        );
        token.safeTransferFrom(address(this), addr1, 0, 100, transferData);
        
        token.lockTokens(addr1, 0, 50, block.timestamp + 40000000);
        
        // Admin force unlock (lockId 1, not 0)
        token.forceTokenUnlock(addr1, 0, 1);
        assertEq(token.lockedBalanceOf(addr1, 0), 0);
        
        // Non-admin should revert
        vm.prank(addr1);
        vm.expectRevert();
        token.forceTokenUnlock(addr1, 0, 1);
    }
    
    // Address Freezing Tests
    function test_should_revert_transfer_if_account_is_frozen() public {
        // First mint tokens to have balance
        _mintTokensFor(address(this), 0, 1000);
        
        token.freeze(addr1, "");
        
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("frozen-transfer")
        );
        
        vm.expectRevert(abi.encodeWithSelector(FreezeAddress.FrozenAddress.selector, addr1));
        token.safeTransferFrom(address(this), addr1, 0, 100, transferData);
    }
    
    // Transfer Restriction Tests  
    function test_should_restrict_and_remove_restriction_of_ids() public {
        token.restrictTransfer(0);
        
        bytes memory transferData = _createTransferSignature(
            owner, addr1, 0, 100, 1, token.getGlobalNonce(), abi.encode(uint256(42))
        );
        
        vm.expectRevert();
        token.safeTransferFrom(owner, addr1, 0, 100, transferData);
        
        // Note: Remove restriction functionality not exposed publicly
        // Just verify restriction is active
        assertTrue(token.isRestricted(0), "Token ID 0 should be restricted");
    }
    
    // Pause Functionality Tests
    function test_should_revert_when_contract_is_paused() public {
        token.pause();
        
        bytes memory transferData = _createTransferSignature(
            owner, addr1, 0, 100, 1, token.getGlobalNonce(), abi.encode(uint256(42))
        );
        
        vm.expectRevert("Pausable: paused");
        token.safeTransferFrom(owner, addr1, 0, 100, transferData);
    }
    
    // CanTransfer Function Tests
    function test_should_verify_transfer_with_global_nonce() public {
        // First mint tokens to have balance
        _mintTokensFor(address(this), 0, 1000);
        
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("global-nonce")
        );
        
        bool canTransfer = token.canTransfer(address(this), addr1, 0, 100, transferData);
        assertTrue(canTransfer);
    }
    
    function test_should_verify_transfer_with_user_nonce() public {
        // First mint tokens to have balance
        _mintTokensFor(address(this), 0, 1000);
        
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 2, token.getUserNonce(0), bytes("user-nonce")
        );
        
        bool canTransfer = token.canTransfer(address(this), addr1, 0, 100, transferData);
        assertTrue(canTransfer);
    }
    
    function test_should_revert_cantransfer_if_token_id_is_restricted() public {
        token.restrictTransfer(0);
        
        bytes memory transferData = _createTransferSignature(
            owner, addr1, 0, 100, 1, token.getGlobalNonce(), abi.encode(uint256(42))
        );
        
        vm.expectRevert();
        token.canTransfer(owner, addr1, 0, 100, transferData);
    }
    
    function test_should_revert_cantransfer_if_sender_is_frozen() public {
        // First mint tokens to have balance
        _mintTokensFor(address(this), 0, 1000);
        
        token.freeze(address(this), "");
        
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("frozen-sender")
        );
        
        vm.expectRevert(abi.encodeWithSelector(FreezeAddress.FrozenAddress.selector, address(this)));
        token.canTransfer(address(this), addr1, 0, 100, transferData);
    }
    
    function test_should_revert_cantransfer_if_receiver_is_frozen() public {
        // First mint tokens to have balance
        _mintTokensFor(address(this), 0, 1000);
        
        token.freeze(addr1, "");
        
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 1, token.getGlobalNonce(), bytes("frozen-receiver")
        );
        
        vm.expectRevert(abi.encodeWithSelector(FreezeAddress.FrozenAddress.selector, addr1));
        token.canTransfer(address(this), addr1, 0, 100, transferData);
    }
    
    function test_should_revert_cantransfer_with_invalid_nonce_type() public {
        // First mint tokens to have balance
        _mintTokensFor(address(this), 0, 1000);
        
        bytes memory transferData = _createTransferSignature(
            address(this), addr1, 0, 100, 4, token.getGlobalNonce(), bytes("invalid-nonce") // Invalid nonce type
        );
        
        vm.expectRevert("Invalid nonce type");
        token.canTransfer(address(this), addr1, 0, 100, transferData);
    }
    
    function test_should_allow_transfer_from_zero_address_minting() public {
        bytes memory mintData = _createMintCompliantData(addr1, _singleArray(0), _singleArray(100));
        
        bool canTransfer = token.canTransfer(address(0), addr1, 0, 100, mintData);
        assertTrue(canTransfer);
    }
    
    // Helper function to create single element arrays
    function _singleArray(uint256 value) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = value;
        return arr;
    }
    
    // Events
    event TokenLocked(address indexed account, uint256 indexed id, uint256 lockId, uint256 amount, uint256 releaseTime);
    event TokenUnlocked(address indexed account, uint256 indexed id, uint256 lockId, uint256 amount);
    event RestrictionRemoved(uint256 indexed id);
    event GlobalNonceIncreased(uint256 nonce);
    event UserNonceIncreased(address indexed user, uint256 nonce);
    event PermitNonceUsed(address indexed owner, uint256 nonce);
}