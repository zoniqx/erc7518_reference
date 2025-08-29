// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;


/**
 * @title Payout
 * @dev allow token holders to receive payouts or dividends.
 * @author Rajat K
 */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

abstract contract Payout is Context {
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event PayoutAddressChanged(
        address previousAddress,
        address indexed newAddress
    );
    event PayoutDelivered(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    address internal _payoutAddress;

    /* -------------------------------------------------------------------------- */
    /*                               External function                            */
    /* -------------------------------------------------------------------------- */

    function payoutAddress() external view virtual returns (address) {
        return _payoutAddress;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal function                             */
    /* -------------------------------------------------------------------------- */

    function _changePayoutAddress(address newAddress) internal virtual {
        emit PayoutAddressChanged(_payoutAddress, newAddress);
        _payoutAddress = newAddress;
    }

    /**
     * @notice Transfers the specified amount of tokens erc token from the sender to the recipient.
     * @param to The address of the recipient to receive the payout.
     * @param amount The amount of tokens to transfer as payout.
     */
    function _payout(address to, uint256 amount) internal virtual {
        ERC20(_payoutAddress).transferFrom(_msgSender(), to, amount);
        emit PayoutDelivered(_msgSender(), to, amount);
    }

    uint256[50] private __gap;
}
