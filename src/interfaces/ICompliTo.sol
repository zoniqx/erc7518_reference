// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

interface ICompliTo {
    function verifySignature(
        address from,
        address to,
        uint id,
        uint amount,
        uint8 nonceType,
        uint nonce,
        bytes memory metadata,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool);

    function batchVerifySignature(
        address from,
        address to,
        uint[] calldata ids,
        uint[] calldata amounts,
        uint8 nonceType,
        uint nonce,
        bytes memory metadata,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool);

    function version() external pure returns (string memory);
}
