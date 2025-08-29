// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

/**
 * @title STO for security token
 * @author Rajat K
 */

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {PaymentTracker} from "./module/PaymentTracker.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC7518} from "./interfaces/IERC7518.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC2771Context} from "./module/ERC2771Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract STOBaseV2 is
    AccessControl,
    ReentrancyGuard,
    PaymentTracker,
    ERC1155Holder,
    ERC2771Context,
    Pausable
{

    bool private _closeSale;
    uint8 public immutable decimals;
    uint256 internal tokensForSale;
    uint256 internal totalTokensForSale;
    uint256 public basePrice;

    address internal immutable _issuer;

    mapping(address => bool) public lockAddress;
    mapping(address => uint256) public tokensBought;

    IERC20Metadata internal immutable _stableCoin;
    IERC7518 internal immutable _tokenContract;

    event SaleStatusUpdated(bool status);
    event AddressLocked(address userAddress);
    event AddressUnlocked(address userAddress);
    event TokenPriceUpdated(uint256 newPrice);
    event TokensBought(
        address indexed userAddress,
        uint indexed id,
        uint256 amount
    );

    /**
     * @notice Constructor for the STO
     *  @param stableCoin address of payment token
     *  @param _tokenContractAddress adress of the deal token
     *  @param _tokensForSale amount of token for the STO.
     *  @param _tokenPrice price of token 1e6 format
     */

    constructor(
        uint256 _tokensForSale,
        uint256 _tokenPrice,
        address stableCoin,
        address _tokenContractAddress,
        address _forwarderAddress,
        address _sender
    ) ERC2771Context(_forwarderAddress) {
        require(stableCoin != address(0), "StableCoin address cannot be zero");
        require(
            _tokenContractAddress != address(0),
            "Token Contract Address address cannot be zero"
        );
        require(
            _forwarderAddress != address(0),
            "Forwarder Address address cannot be zero"
        );
        require(_sender != address(0), "Sender address cannot be zero");

        _stableCoin = IERC20Metadata(stableCoin);
        _tokenContract = IERC7518(_tokenContractAddress);
        decimals = 18;
        _issuer = _sender;
        tokensForSale = _tokensForSale;
        totalTokensForSale = _tokensForSale;
        basePrice = _tokenPrice;
    }

    /* -------------------------------------------------------------------------- */
    /*                             External Functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice change ERC2771 trusted forwarder
     * @dev only admin can change the trusted forwarder
     * @param forwarder address of the trusted forwarder
     */
    function setTrustedForwarder(
        address forwarder
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTrustedForwarder(forwarder);
    }

    function tokenForSale() external view returns (uint256) {
        return totalTokensForSale;
    }

    function getTotalTokenSold() external view virtual returns (uint256) {
        return totalTokensForSale - tokenAvailableForSale();
    }

    /**
     * @notice  get the token balance of the contract which user can
     */
    function tokenAvailableForSale() public view virtual returns (uint256) {
        return tokensForSale;
    }

    function closeSto() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _closeSale = true;
        emit SaleStatusUpdated(_closeSale);
    }

    function status() external view returns (bool) {
        return _closeSale;
    }

    function markAddressAsLocked(
        address _userAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        lockAddress[_userAddress] = true;
        emit AddressLocked(_userAddress);
    }

    function getIssuer() external view returns (address) {
        return _issuer;
    }

    function unlockUserAddress(
        address _userAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        lockAddress[_userAddress] = false;
        emit AddressUnlocked(_userAddress);
    }

    // function to update the price of the tokens;

    function updateTokenPrice(
        uint256 _price
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        basePrice = _price;
        emit TokenPriceUpdated(_price);
    }

    modifier isSTOActive() {
        _requireNotPaused();
        require(!_closeSale, "STO: is expired");
        _;
    }

    /**
     * @dev get stable coin  address
     */

    function getStableCoinAddress() external view returns (address) {
        return address(_stableCoin);
    }

    /**
     * @dev get security token address
     */

    function getSecurityTokenAddress() external view returns (address) {
        return address(_tokenContract);
    }

    /**
     * @notice Settlement of token on-chain.
     * @param amount No of tokens to buy without decimals.
     * @param account address of the user who will receive the security token.
     * @param investmentId unique id to track investment on off-chain side.
     * @param data to pass to ERC1155 token.
     * @return bool
     */
    function bankTransferSettlement(
        uint256 amount,
        uint256 id,
        uint256 lockinPeriod,
        address account,
        string calldata investmentId,
        bytes calldata data
    )
        external
        virtual
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        _beforeTokenPurchase(amount, account, investmentId);
        _tokenSettlement(
            account,
            amount,
            lockinPeriod,
            id,
            InvestmentType.Fiat,
            investmentId,
            data
        );
        return true;
    }

    /**
     * @notice refund balance from sto to owner.
     * @param data to pass to ERC1155 token.
     */

    function refundBalance(
        bytes calldata data,
        uint256 id
    ) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_closeSale, "Can't refund before sto expiry");
        IERC1155(address(_tokenContract)).safeTransferFrom(
            address(this),
            _msgSender(),
            id,
            tokenAvailableForSale(),
            data
        );
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Function                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice transfer token to the investor.
     * @dev should be called before the lockin.
     */
    function _transferTokensToInvestor(
        address account,
        uint id,
        uint256 amount,
        bytes calldata data
    ) internal virtual returns (bool) {
        tokensBought[account] = tokensBought[account] + amount;
        tokensForSale = tokensForSale - amount;
        IERC1155(address(_tokenContract)).safeTransferFrom(
            address(this),
            account,
            id,
            amount,
            data
        );
        return true;
    }

    /**
     * @notice lock token for the investor.
     * @dev should be called after token are transfered.
     */
    function _lockToken(
        uint amount,
        uint lockinPeriod,
        uint id,
        address account
    ) internal {
        uint256 lockInUntil = block.timestamp + (lockinPeriod * 1 days);
        bool lockedstatus = _tokenContract.lockTokens(
            account,
            id,
            amount,
            lockInUntil
        );
        require(lockedstatus, "STO: lock failed");
    }

    /**
     * @notice verify all the condition before buying the token.
     * @dev check for duplicate investment id and lock wallet.
     */
    function _beforeTokenPurchase(
        uint _amount,
        address sender,
        string memory _investmentId
    ) internal view virtual isSTOActive {
        require(!lockAddress[sender], "STO: Wallet locked");
        require(
            investmentDetails[_investmentId].userAddress == address(0),
            "STO: Duplicate investment Id"
        );
    }

    /**
     * @notice Settles the token purchase and locks the tokens for a specified period.
     * @dev Handles the transfer of tokens to the investor, locks the tokens for the lock-in period,
     *      and records the investment details. Emits a `TokensBought` event.
     * @param account The address of the investor receiving the tokens.
     * @param amount The amount of tokens to transfer to the investor.
     * @param lockinPeriod The period for which the tokens will be locked.
     * @param id The ID associated with the token being transferred.
     * @param investment The type of investment being made.
     * @param investmentId The unique ID of the investment.
     * @param data compliTo signature used for minting tokens to the investor.
     */
    function _tokenSettlement(
        address account,
        uint256 amount,
        uint256 lockinPeriod,
        uint256 id,
        InvestmentType investment,
        string calldata investmentId,
        bytes calldata data
    ) internal virtual {
        _transferTokensToInvestor(account, id, amount, data);
        _lockToken(amount, lockinPeriod, id, account);
        investmentDetails[investmentId] = Investment(
            account,
            amount,
            investmentId,
            investment,
            InvestmentStatus.Settled
        );
        emit TokensBought(account, id, amount);
    }

    /**
     * @dev transfer stable coin from investor to issuer. for calculating
     */
    function _transferStableCoin(
        address sender,
        uint amount,
        uint tokenPrice
    ) internal {
        uint256 tokenAmount = (tokenPrice * amount) / (10 ** decimals);
        require(
            _stableCoin.transferFrom(sender, _issuer, tokenAmount),
            "Stablecoin: payment failed"
        );
    }

    /**
     * @dev Extract sender address from the meta transcation
     * @return address
     */
    function _msgSender()
        internal
        view
        virtual
        override(ERC2771Context, Context)
        returns (address)
    {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev Extract sender data from the meta transcation
     * @return data
     */
    function _msgData()
        internal
        view
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControl, ERC1155Receiver)
        returns (bool)
    {
        return
            AccessControl.supportsInterface(interfaceId) ||
            ERC1155Receiver.supportsInterface(interfaceId);
    }

    /**
     * @dev Denote the current version of the contract.
     * @return string "Major"."Minor"."Patch" format.
     */
    function version() external pure virtual returns (string memory) {
        return "0.0.1";
    }
}
