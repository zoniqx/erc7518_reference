// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/ERC7518.sol";
import "../src/CompliTo.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../src/module/FreezeAddress.sol";
import "../src/module/TokenLock.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract ERC7518Test is Test, ERC1155Holder {
    ERC7518 token;
    CompliTo c;
    MockERC20 usdc;
    
    address admin = address(this);
    address addr1 = address(0x1111);
    address addr2 = address(0x2222);
    address addr3 = address(0x3333);
    address forwarder = address(0xc65d82ECE367EF06bf2AB791B3f3CF037Dc0e816);
    
    // signer for CompliTo validator role
    uint256 private validatorPk;
    address private validator;
    
    bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function setUp() public {
        // choose a real private key for the validator, derive its address
        validatorPk = 0xA11CE;
        validator = vm.addr(validatorPk);
        
        // Deploy CompliTo with validator
        c = new CompliTo(validator);
        
        // Deploy mock USDC
        usdc = new MockERC20();
        usdc.mint(address(this), 10000 * 1e6);
        
        // Deploy ERC7518 via proxy
        ERC7518 impl = new ERC7518();
        bytes memory initData = abi.encodeWithSelector(
            ERC7518.initialize.selector,
            "ipfs://base.json",
            address(c),
            forwarder,
            address(usdc),
            admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        token = ERC7518(address(proxy));
        
        // Mint some USDC to test addresses
        usdc.mint(addr1, 1000 * 1e6);
        usdc.mint(addr2, 1000 * 1e6);
    }

    function test_roles_are_assigned() public {
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, admin), "admin should have DEFAULT_ADMIN_ROLE");
        assertTrue(token.hasRole(token.URI_SETTER_ROLE(), admin), "admin has URI_SETTER_ROLE");
        assertTrue(token.hasRole(token.PAYOUT_ROLE(), admin), "admin has PAYOUT_ROLE");
        assertTrue(token.hasRole(token.PAUSER_ROLE(), admin), "admin has PAUSER_ROLE");
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin), "admin has MINTER_ROLE");
    }

    function test_pause_unpause_and_setURI() public {
        token.pause();
        token.unpause();
        token.setURI("ipfs://new.json");
    }
    
    // Helper functions
    function _getDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256(bytes("CompliTo")),
            keccak256(bytes("1.0.0")),
            block.chainid,
            address(c)
        ));
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
        bytes32 typehash = c.EIP712_SET_TRANSFER_APPROVAL_TYPEHASH();
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
    
    function _mintTokensFor(address to, uint256 id, uint256 amount) internal {
        bytes memory mintData = _createTransferSignature(
            address(0), to, id, amount, 1, token.getGlobalNonce(), bytes("mint-meta")
        );
        token.mint(to, id, amount, mintData);
    }
    
    // ============ MINT TOKEN TESTS ============
    
    function test_should_revert_if_token_not_minted_by_minter() public {
        vm.prank(addr1);
        vm.expectRevert();
        token.mint(admin, 0, 2, "0x");
    }
    
    function test_should_revert_if_owner_address_is_zero_in_constructor() public {
        ERC7518 impl = new ERC7518();
        
        // Test zero owner address
        bytes memory initData1 = abi.encodeWithSelector(
            ERC7518.initialize.selector,
            "ipfs://base.json",
            address(c),
            forwarder,
            address(usdc),
            address(0)
        );
        vm.expectRevert(abi.encodeWithSelector(ERC7518.ZeroAddress.selector));
        new ERC1967Proxy(address(impl), initData1);
        
        // Test zero compliance address
        bytes memory initData2 = abi.encodeWithSelector(
            ERC7518.initialize.selector,
            "ipfs://base.json",
            address(0),
            forwarder,
            address(usdc),
            admin
        );
        vm.expectRevert(abi.encodeWithSelector(ERC7518.ZeroAddress.selector));
        new ERC1967Proxy(address(impl), initData2);
    }
    
    function test_should_add_token_when_minted_by_minter() public {
        uint256 amountToBeMinted = 20 ether;
        uint256 initialBalance = token.balanceOf(admin, 0);
        
        _mintTokensFor(admin, 0, amountToBeMinted);
        
        uint256 finalBalance = token.balanceOf(admin, 0);
        assertEq(finalBalance - initialBalance, amountToBeMinted);
    }
    
    function test_should_revert_if_initialize_called_again() public {
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize(
            "www.example.com/uri/",
            address(c),
            forwarder,
            address(usdc),
            admin
        );
    }
    
    function test_should_batch_mint() public {
        uint256 amountToBeMinted = 200 ether;
        uint256 addr1Balance0 = token.balanceOf(addr1, 0);
        uint256 addr1Balance1 = token.balanceOf(addr1, 1);
        
        uint256 currentGlobalNonce = token.getGlobalNonce();
        
        bytes memory sig0 = _createTransferSignature(
            address(0), addr1, 0, amountToBeMinted, 1, currentGlobalNonce, bytes("batch-mint-0")
        );
        bytes memory sig1 = _createTransferSignature(
            address(0), addr1, 1, amountToBeMinted, 1, currentGlobalNonce + 1, bytes("batch-mint-1")
        );
        
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = sig0;
        signatures[1] = sig1;
        
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountToBeMinted;
        amounts[1] = amountToBeMinted;
        
        token.mintBatch(addr1, ids, amounts, signatures);
        
        assertEq(token.balanceOf(addr1, 0), addr1Balance0 + amountToBeMinted);
        assertEq(token.balanceOf(addr1, 1), addr1Balance1 + amountToBeMinted);
    }
    
    function test_should_set_uri() public {
        string memory oldUri = token.uri(0);
        token.setURI("newUri");
        string memory newUri = token.uri(0);
        assertTrue(keccak256(bytes(oldUri)) != keccak256(bytes(newUri)));
    }
    
    function test_should_revert_if_uri_not_set_by_uri_setter() public {
        vm.prank(addr1);
        vm.expectRevert();
        token.setURI("newUri");
    }
    
    function test_should_return_correct_version() public {
        assertEq(token.version(), "3.0.0");
    }
    
    function test_should_pause_unpause_contract() public {
        token.pause();
        assertTrue(token.paused());
        
        // Should revert when paused
        vm.expectRevert("Pausable: paused");
        token.mintBatch(addr1, new uint256[](0), new uint256[](0), new bytes[](0));
        
        vm.expectRevert("Pausable: paused");
        token.mint(admin, 0, 10000 ether, "0x");
        
        token.unpause();
        assertFalse(token.paused());
        
        // Non-admin should revert
        vm.prank(addr1);
        vm.expectRevert();
        token.pause();
        
        vm.prank(addr1);
        vm.expectRevert();
        token.unpause();
    }
    
    // ============ FROZEN/UNFREEZE TESTS ============
    
    function test_should_freeze_unfreeze_account() public {
        token.freeze(addr1, "");
        assertTrue(token.isFrozen(addr1));
        
        token.unFreeze(addr1, "");
        assertFalse(token.isFrozen(addr1));
    }
    
    function test_should_revert_if_freeze_unfreeze_called_by_non_admin() public {
        vm.prank(addr1);
        vm.expectRevert();
        token.freeze(addr1, "");
        
        vm.prank(addr1);
        vm.expectRevert();
        token.unFreeze(addr1, "");
    }
    
    // ============ PAYOUT TESTS ============
    
    function test_should_change_payout_address() public {
        token.changePayoutAddress(address(usdc));
        assertEq(token.payoutAddress(), address(usdc));
        
        vm.prank(addr1);
        vm.expectRevert();
        token.changePayoutAddress(address(usdc));
    }
    
    function test_should_transfer_dividend() public {
        // Test with zero address should revert
        address[] memory recipients = new address[](2);
        recipients[0] = address(0);
        recipients[1] = addr2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = 20 * 1e6;
        
        vm.expectRevert(abi.encodeWithSelector(ERC7518.ZeroAddress.selector));
        token.batchPayout(recipients, amounts);
        
        // Test invalid array lengths
        recipients = new address[](2);
        recipients[0] = addr1;
        recipients[1] = addr2;
        
        amounts = new uint256[](1);
        amounts[0] = 10 * 1e6;
        
        vm.expectRevert(abi.encodeWithSelector(ERC7518.InvalidArgLen.selector));
        token.batchPayout(recipients, amounts);
        
        // Test frozen address should revert
        token.freeze(addr3, "");
        recipients = new address[](2);
        recipients[0] = addr3;
        recipients[1] = addr2;
        
        amounts = new uint256[](2);
        amounts[0] = 10 * 1e6;
        amounts[1] = 20 * 1e6;
        
        usdc.approve(address(token), 30 * 1e6);
        vm.expectRevert(abi.encodeWithSelector(FreezeAddress.FrozenAddress.selector, addr3));
        token.batchPayout(recipients, amounts);
        
        // Successful batch payout
        token.unFreeze(addr3, "");
        recipients[0] = addr1;
        
        uint256 ownerBalanceBefore = usdc.balanceOf(admin);
        uint256 addr1BalanceBefore = usdc.balanceOf(addr1);
        uint256 addr2BalanceBefore = usdc.balanceOf(addr2);
        
        token.batchPayout(recipients, amounts);
        
        assertEq(usdc.balanceOf(admin), ownerBalanceBefore - 30 * 1e6);
        assertEq(usdc.balanceOf(addr1), addr1BalanceBefore + 10 * 1e6);
        assertEq(usdc.balanceOf(addr2), addr2BalanceBefore + 20 * 1e6);
        
        // Single payout test
        usdc.approve(address(token), 5 * 1e6);
        uint256 ownerBalanceBefore2 = usdc.balanceOf(admin);
        uint256 addr1BalanceBefore2 = usdc.balanceOf(addr1);
        
        vm.expectEmit(true, true, true, true);
        emit PayoutDelivered(admin, addr1, 5 * 1e6);
        
        token.payout(addr1, 5 * 1e6);
        
        assertEq(usdc.balanceOf(admin), ownerBalanceBefore2 - 5 * 1e6);
        assertEq(usdc.balanceOf(addr1), addr1BalanceBefore2 + 5 * 1e6);
    }
    
    function test_should_revert_if_dividend_paid_by_non_payout_role() public {
        address[] memory recipients = new address[](2);
        recipients[0] = addr1;
        recipients[1] = addr2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 * 1e6;
        amounts[1] = 10 * 1e6;
        
        vm.prank(addr1);
        vm.expectRevert();
        token.batchPayout(recipients, amounts);
        
        vm.prank(addr1);
        vm.expectRevert();
        token.payout(addr1, 10 * 1e6);
    }
    
    // ============ FORCE TRANSFER TESTS ============
    
    function test_should_force_transfer() public {
        _mintTokensFor(addr1, 0, 200 ether);
        
        uint256 oldBalanceAccount1 = token.balanceOf(addr1, 0);
        uint256 oldBalanceAccount2 = token.balanceOf(addr2, 0);
        
        token.freeze(addr1, "");
        token.forceTransfer(addr1, addr2, 0, oldBalanceAccount1, "");
        
        uint256 newBalanceAccount2 = token.balanceOf(addr2, 0);
        assertEq(newBalanceAccount2 - oldBalanceAccount2, oldBalanceAccount1);
        assertEq(token.balanceOf(addr1, 0), 0);
    }
    
    function test_should_revert_if_force_transfer_used_by_non_admin() public {
        vm.prank(addr1);
        vm.expectRevert();
        token.forceTransfer(admin, addr1, 0, 200 ether, "");
    }
    
    // ============ BURN TOKEN TESTS ============
    
    function test_should_burn_token() public {
        uint256 balanceToBeBurned = 20 ether;
        _mintTokensFor(admin, 0, balanceToBeBurned);
        
        uint256 oldBalance = token.balanceOf(admin, 0);
        token.burn(admin, 0, balanceToBeBurned);
        uint256 newBalance = token.balanceOf(admin, 0);
        
        assertEq(oldBalance - newBalance, balanceToBeBurned);
    }
    
    // ============ EVENTS ============
    
    event PayoutDelivered(address indexed from, address indexed to, uint256 amount);
}