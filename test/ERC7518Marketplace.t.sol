// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/ERC7518MarketPlace.sol";
import "../src/ERC7518.sol";
import "../src/CompliTo.sol";
import "./mocks/MockBeacon.sol";

contract ERC7518MarketplaceTest is Test {
    ERC7518Marketplace market;
    CompliTo compliTo;
    MockBeacon beacon;
    ERC7518 impl;

    address forwarder = address(0xF0F0);
    address compliance = address(0xC0FFEE);
    address payout = address(0xBEEF01);
    address user = address(0xABCD);

    function setUp() public {
        compliTo = new CompliTo(address(this));
        impl = new ERC7518();
        beacon = new MockBeacon(address(impl));
        market = new ERC7518Marketplace(forwarder, address(compliTo), payout, beacon);
        market.whitelist(user);
    }

    function test_create_deploys_contract() public {
        vm.prank(user);
        address contractAddr = market.create("ipfs://deal.json", "DEAL-1");

        ERC7518 deployedContract = ERC7518(contractAddr);
        assertEq(deployedContract.uri(0), "ipfs://deal.json");
        assertTrue(deployedContract.hasRole(deployedContract.DEFAULT_ADMIN_ROLE(), user));
    }

    function test_duplicate_dealId_reverts() public {
        vm.prank(user);
        market.create("uri-a", "DEAL-2");
        vm.prank(user);
        vm.expectRevert();
        market.create("uri-b", "DEAL-2");
    }

    function test_change_admin_params() public {
        market.changeForwarderAddress(address(0xF1));
        assertEq(market.forwarderAddress(), address(0xF1));

        MockBeacon newBeacon = new MockBeacon(address(impl));
        market.changeBeaconAddress(newBeacon);
        assertEq(market.beaconAddress(), address(newBeacon));

        market.changeComplianceAddress(address(0xC1));
        assertEq(market.complianceAddress(), address(0xC1));

        market.changePayoutAddress(address(0xBEEF02));
        assertEq(market.payoutAddress(), address(0xBEEF02));
    }

    function test_deal_token_creation_with_events() public {
        market.whitelist(admin);
        
        vm.prank(admin);
        vm.expectEmit(true, false, true, true);
        emit DealInstantiation(admin, address(0), "DEAL-1");
        
        address tokenAddr = market.create("ipfs://deal.json", "DEAL-1");
        
        assertTrue(tokenAddr != address(0), "Token should be deployed");
    }

    function test_zero_address_validation_forwarder() public {
        vm.expectRevert("Zero address");
        new ERC7518Marketplace(address(0), address(compliTo), payout, beacon);
    }

    function test_zero_address_validation_compliance() public {
        vm.expectRevert("Zero address");
        new ERC7518Marketplace(forwarder, address(0), payout, beacon);
    }

    function test_zero_address_validation_payout() public {
        vm.expectRevert("Zero address");
        new ERC7518Marketplace(forwarder, address(compliTo), address(0), beacon);
    }

    function test_zero_address_validation_beacon() public {
        vm.expectRevert("Zero address");
        new ERC7518Marketplace(forwarder, address(compliTo), payout, MockBeacon(address(0)));
    }

    function test_only_whitelisted_can_create() public {
        vm.prank(admin);
        vm.expectRevert("Only whitelist");
        market.create("ipfs://deal.json", "DEAL-FAIL");
    }

    function test_duplicate_whitelist_fails() public {
        vm.expectRevert("MarketPlace: User already whiteListed");
        market.whitelist(user);
    }

    function test_deal_count_tracking() public {
        market.whitelist(admin);
        
        for(uint i = 0; i < 5; i++) {
            vm.prank(admin);
            market.create(string(abi.encodePacked("ipfs://deal", vm.toString(i), ".json")), 
                         string(abi.encodePacked("DEAL-", vm.toString(i))));
        }
        
        assertEq(market.getDealsCount(admin), 5, "Should have 5 deals");
    }

    function test_version_check() public {
        assertEq(market.version(), "2.2.0", "Version should be 2.2.0");
    }

    function test_change_forwarder_address_access_control() public {
        vm.prank(admin);
        vm.expectRevert("Ownable: caller is not the owner");
        market.changeForwarderAddress(address(0xF1));
        
        vm.expectRevert("Zero address");
        market.changeForwarderAddress(address(0));
        
        market.changeForwarderAddress(address(0xF1));
        assertEq(market.forwarderAddress(), address(0xF1));
    }

    function test_change_compliance_address_access_control() public {
        vm.prank(admin);
        vm.expectRevert("Ownable: caller is not the owner");
        market.changeComplianceAddress(address(0xC1));
        
        vm.expectRevert("Zero address");
        market.changeComplianceAddress(address(0));
        
        market.changeComplianceAddress(address(0xC1));
        assertEq(market.complianceAddress(), address(0xC1));
    }

    function test_whitelist_removal() public {
        assertTrue(market.whiteListUsers(user), "User should be whitelisted initially");
        
        market.removeWhiteList(user);
        assertFalse(market.whiteListUsers(user), "User should be removed from whitelist");
        
        vm.prank(admin);
        vm.expectRevert("Ownable: caller is not the owner");
        market.removeWhiteList(user);
    }

    function test_deal_token_roles_assignment() public {
        market.whitelist(admin);
        
        vm.prank(admin);
        address tokenAddr = market.create("ipfs://deal.json", "DEAL-ROLES");
        
        ERC7518 dealToken = ERC7518(tokenAddr);
        
        assertTrue(dealToken.hasRole(dealToken.DEFAULT_ADMIN_ROLE(), admin), "Admin should have default admin role");
        assertTrue(dealToken.hasRole(dealToken.URI_SETTER_ROLE(), admin), "Admin should have URI setter role");
        assertTrue(dealToken.hasRole(dealToken.MINTER_ROLE(), admin), "Admin should have minter role");
    }

    function test_deal_token_compliance_verification() public {
        market.whitelist(admin);
        
        vm.prank(admin);
        address tokenAddr = market.create("ipfs://deal.json", "DEAL-COMPLIANCE");
        
        ERC7518 dealToken = ERC7518(tokenAddr);
        
        assertEq(dealToken.compliTO(), address(compliTo), "Compliance address should match marketplace compliance");
    }

    address admin = address(0x1234);
    
    event DealInstantiation(address indexed issuer, address indexed token, string dealId);
}