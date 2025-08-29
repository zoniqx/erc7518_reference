// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

/**
 * @title Lock ERC1155 Tokens
 * @author Rajat K
 */
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
// import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
abstract contract TokenLock {
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event TokenLocked(
        address indexed account,
        uint256 indexed id,
        uint lockId,
        uint256 amount,
        uint256 releaseTime
    );
    event TokenUnlocked(
        address indexed account,
        uint256 indexed id,
        uint256 lockId,
        uint256 amount
    );

    event ForcedTokenUnlocked(
        address indexed agent,
        address indexed account,
        uint256 indexed id,
        uint256 lockId,
        uint256 amount
    );
    struct Lock {
        uint256 releaseTime;
        uint256 amount;
        bool claimed;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */
    error TokenAlreadyUnlock(uint lockId);
    error NoTokensToUnlock();

    /* -------------------------------------------------------------------------- */
    /*                                   Stroage                                  */
    /* -------------------------------------------------------------------------- */
    using Counters for Counters.Counter;
    Counters.Counter internal _currentLockId;

    mapping(address => mapping(uint => uint256[])) public lockIds;
    mapping(address => mapping(uint => mapping(uint256 => Lock))) public locked;
    mapping(address => mapping(uint256 => uint256))
        internal _lockedTokenAmounts;

    /* -------------------------------------------------------------------------- */
    /*                              Public function                               */
    /* -------------------------------------------------------------------------- */
    function lockedBalanceOf(
        address account,
        uint256 id
    ) public view returns (uint256) {
        return _lockedTokenAmounts[account][id];
    }

    /**
     * @notice Unlocks tokens for a specified account and lock ID.
     * @dev Iterates through all lock IDs associated with the provided account and lock ID,
     *      unlocking tokens if the release time has passed and they haven't been claimed yet.
     * @param account The address of the account for which tokens are to be unlocked.
     * @param id The ID associated with the token lock.
     */
    function unlockTokens(address account, uint id) external virtual {
        uint256 amount;
        uint[] memory arrLockIds = lockIds[account][id];
        for (uint256 i = 0; i < arrLockIds.length; ) {
            uint lockId = arrLockIds[i];
            Lock storage tokensLocked = locked[account][id][lockId];
            if (
                tokensLocked.releaseTime <= block.timestamp &&
                !tokensLocked.claimed
            ) {
                amount += tokensLocked.amount;
                tokensLocked.claimed = true;
                emit TokenUnlocked(account, id, lockId, amount);
            }
            unchecked {
                i += 1;
            }
        }
        if (amount <= 0) revert NoTokensToUnlock();
        _lockedTokenAmounts[account][id] -= amount;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal function                         */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Forces the unlocking of tokens for a specified account and lock ID by an agent.
     * @dev Allows an agent to unlock tokens even if the release time has not been reached.
     *      Marks the tokens as claimed.
     * @param agent The address of the agent performing the forced unlock.
     * @param account The address of the account whose tokens are to be forcibly unlocked.
     * @param id The ID associated with the token lock.
     * @param lockId The specific lock ID of the tokens to be unlocked.
     */
    function _forceTokenUnlock(
        address agent,
        address account,
        uint id,
        uint lockId
    ) internal virtual {
        Lock storage tokensLocked = locked[account][id][lockId];
        if (tokensLocked.claimed) revert TokenAlreadyUnlock(lockId);
        tokensLocked.claimed = true;
        emit ForcedTokenUnlocked(
            agent,
            account,
            id,
            lockId,
            tokensLocked.amount
        );
        _lockedTokenAmounts[account][id] -= tokensLocked.amount;
    }

    /**
     * @notice Locks a specified amount of tokens for an account until a specified release time.
     * @dev Creates a new lock for the specified amount of tokens, increments the current lock ID,
     *      and stores the lock information. Emits a `TokenLocked` event.
     * @param account The address of the account for which tokens are to be locked.
     * @param id The ID associated with the token lock.
     * @param amount The amount of tokens to be locked.
     * @param releaseTime The timestamp after which the tokens can be unlocked.
     */
    function _lockTokens(
        address account,
        uint256 id,
        uint256 amount,
        uint256 releaseTime
    ) internal virtual {
        _currentLockId.increment();
        uint256 _lockId = _currentLockId.current();
        _lockedTokenAmounts[account][id] += amount;
        locked[account][id][_lockId] = Lock({
            amount: amount,
            releaseTime: releaseTime,
            claimed: false
        });
        lockIds[account][id].push(_lockId);
        emit TokenLocked(account, id, _lockId, amount, releaseTime);
    }

    uint256[50] private __gap;
}
