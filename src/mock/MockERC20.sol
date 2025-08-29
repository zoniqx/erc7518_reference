// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "MCK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
