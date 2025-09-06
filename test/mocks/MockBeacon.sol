// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

contract MockBeacon is IBeacon {
    address private _impl;
    constructor(address impl) { _impl = impl; }
    function implementation() external view returns (address) { return _impl; }
    function setImplementation(address impl) external { _impl = impl; }
}