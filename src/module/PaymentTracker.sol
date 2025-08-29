// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

/**
 * @title Track payment details of investment
 * @author Rajat K
 */

abstract contract PaymentTracker {
    enum InvestmentStatus {
        DoesNotExist,
        Opened,
        Settled,
        Canceled
    }
    enum InvestmentType {
        StableCoin,
        Fiat
    }

    // Struct representing an investment
    struct Investment {
        address userAddress;
        uint256 tokenAmount;
        string paymentID;
        InvestmentType iType;
        InvestmentStatus status;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    // Mapping to store investment details by payment ID
    mapping(string => Investment) internal investmentDetails;

    /* -------------------------------------------------------------------------- */
    /*                               Public function                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Retrieves the details of an investment by its ID.
     * @param _investmentId The ID of the investment to retrieve.
     * @return Investment The investment details.
     */
    function getInvestmentDetails(
        string memory _investmentId
    ) public view returns (Investment memory) {
        return (investmentDetails[_investmentId]);
    }
}
