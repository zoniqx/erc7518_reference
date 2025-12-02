// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/ERC7518.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

contract PartitionWrapLifecycleTest is Test {
    ERC7518 token;
    MockToken src;
    address alice = address(0xA11CE);
    bytes32 partitionId = keccak256("PARTITION_A");
    uint256 constant TOKEN_ID = 1001;

    function setUp() public {
        token = new ERC7518();
        src = new MockToken();
        src.mint(alice, 1000 ether);
        vm.startPrank(alice);
        src.approve(address(token), type(uint256).max);
        token.setWrappedTokenAddress(TOKEN_ID, address(src));
    }

    function testFullPartitionLifecycle() public {
        // Wrap ERC-20
        token.wrapToken(TOKEN_ID, 200 ether, "");
        assertEq(token.balanceOf(alice, TOKEN_ID), 200 ether);

        // Wrap from partition (mock call passes)
        vm.mockCall(
            address(src),
            abi.encodeWithSignature(
                "operatorTransferByPartition(bytes32,address,address,uint256,bytes,bytes)",
                partitionId, alice, address(token), 50 ether, "", ""
            ),
            abi.encode(bytes32(0))
        );
        token.wrapTokenFromPartition(partitionId, TOKEN_ID, 50 ether, "");
        assertEq(token.balanceOf(alice, TOKEN_ID), 250 ether);

        // Unwrap
        token.unwrapToken(TOKEN_ID, 100 ether, "");
        assertEq(token.balanceOf(alice, TOKEN_ID), 150 ether);
    }
}