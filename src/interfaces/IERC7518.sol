// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

// import {IERC20Metadata} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC.sol";
interface IERC7518 {
    /**
     * @dev This function allows transferring a specified amount of a token from one address to another.
     * @param from The address from which the tokens will be transferred.
     * @param to The address to which the tokens will be transferred.
     * @param id The identifier of the token being transferred.
     * @param amount The amount of tokens to transfer.
     * @return status A boolean indicating the success or failure of the transfer.
     */

    function canTransfer(
        address from,
        address to,
        uint id,
        uint amount,
        bytes calldata data
    ) external view returns (bool);

    /**
     * @notice Locks a specified amount of tokens from an account for a specified duration.
     * @dev This function can only be called by authorized accounts.
     * @param account The address from which the tokens will be locked.
     * @param id The unique identifier for the locked tokens.
     * @param amount The amount of tokens to be locked.
     * @param releaseTime The timestamp indicating when the tokens will be released.
     * @return A boolean value indicating whether the tokens were successfully locked.
     */

    function lockTokens(
        address account,
        uint id,
        uint256 amount,
        uint256 releaseTime
    ) external returns (bool);

    /**
     * @dev Force transfer in cases like recovery of tokens
     * @param from Old address of investor
     * @param to New address of investor
     * @param id identifier of the tokens being transferred.
     * @param amount No of tokens to transfer
     * @return success status of the tranfer true for transaction completion and revert if failed
     */
    function forceTransfer(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external returns (bool);

    function forceTokenUnlock(
        address account,
        uint256 id,
        uint lockId
    ) external returns (bool);

    /**
     * @notice Freezes the specified address.
     * @dev This function can only be called by authorized accounts.
     * @param account The address to be frozen.
     * @return A boolean value indicating whether the address was successfully frozen.
     */
    function freeze(address account, bytes memory data) external returns (bool);

    /**
     * @notice Unfreezes the specified address.
     * @dev This function can only be called by authorized accounts.
     * @param account The address to be unfrozen.
     * @return A boolean value indicating whether the address was successfully unfrozen.
     */

    function unFreeze(
        address account,
        bytes memory data
    ) external returns (bool);

    /**
     * @dev version of the contract
     * @return string format version
     */
    function version() external pure returns (string memory);

    /**
     * @dev enable/disable users to transfer token externally
     */
    function restrictTransfer(uint id) external returns (bool);

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    /**
     * @notice Registers or updates the address of the underlying security token standard.
     * @param id ERC-1155 tokenId representing the partition of wrapped asset.
     * @dev Token address could be ERC-3643, ERC-1400, or ERC-20 compatible security token.
     */
    function setWrappedTokenAddress(uint256 id, address token) external returns (bool);

    /**
     * @notice Locks the specified amount of source tokens and mints equivalent ERC-1155 tokens.
     * @param id ERC-1155 tokenId to mint for the wrapped representation.
     * @param amount Amount of underlying tokens to lock and wrap.
     * @param data Optional compliance or proof data.
     */
    function wrapToken(uint256 id, uint256 amount, bytes calldata data) external returns (bool);

    /**
     * @notice Locks tokens from a specific partition of the source standard
     *         and mints equivalent ERC-1155 partition tokens.
     * @param partitionId partition identifier.
     * @param id ERC-1155 tokenId corresponding to that partition.
     * @param amount Amount of tokens to wrap.
     * @param data Optional compliance or proof data.
     */
    function wrapTokenFromPartition(
        bytes32 partitionId,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);

    /**
     * @notice Burns the ERC-1155 wrapped tokens and releases the underlying asset.
     * @param wrappedTokenId ERC-1155 tokenId that represents the wrapped asset.
     * @param amount Amount of tokens to unwrap.
     * @param data Optional compliance or proof data.
     */
    function unwrapToken(
        uint256 wrappedTokenId,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);

    event PartitionWrapped(
        bytes32 indexed partitionId,
        uint256 indexed tokenId,
        address indexed operator,
        uint256 amount,
        bytes data
    );

    event PartitionUnwrapped(
        uint256 indexed tokenId,
        address indexed operator,
        uint256 amount,
        bytes data
    );
}
