// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
/**
 * @dev Context variant with ERC2771 support.
 * Here _trustedForwarder is made internal instead of private
 * so it can be changed via Child contracts with a setter method.
 */
abstract contract ERC2771Context is Context {
    event TrustedForwarderChanged(address indexed _tf);

    address internal _trustedForwarder;

    function getTrustedForwarder() external view returns (address) {
        return _trustedForwarder;
    }

    constructor(address trustedForwarder) {
        require(trustedForwarder != address(0), "TrustedForwarder can't be 0");
        _trustedForwarder = trustedForwarder;
    }

    function isTrustedForwarder(
        address forwarder
    ) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function _msgSender()
        internal
        view
        virtual
        override
        returns (address sender)
    {
        if (isTrustedForwarder(msg.sender) && msg.data.length >= 20) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData()
        internal
        view
        virtual
        override
        returns (bytes calldata)
    {
        if (isTrustedForwarder(msg.sender) && msg.data.length >= 20) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    function _setTrustedForwarder(address _tf) internal virtual {
        require(_tf != address(0), "TrustedForwarder can't be 0");
        _trustedForwarder = _tf;
        emit TrustedForwarderChanged(_tf);
    }
}
