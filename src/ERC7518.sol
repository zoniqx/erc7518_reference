// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import {IERC7518} from "./interfaces/IERC7518.sol";
import {ICompliTo} from "./interfaces/ICompliTo.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

// Custom modules
import {ERC1155AllowanceWrapper} from "./module/ERC1155AllowanceWrapper.sol";
import {Nonce} from "./module/Nonce.sol";
import {TokenLock} from "./module/TokenLock.sol";
import {FreezeAddress} from "./module/FreezeAddress.sol";
import {RestrictTransfer} from "./module/RestrictTransfer.sol";
import {Payout} from "./module/Payout.sol";
import {ERC1155Permit} from "./module/ERC1155Permit.sol";

library byteOp {
    function getSignatureComponent(
        bytes memory data
    )
        internal
        pure
        returns (
            uint8 nonceType,
            bytes32 r,
            bytes32 s,
            uint8 v,
            bytes memory metadata
        )
    {
        if (data.length < 66) revert("Invalid signature length");

        assembly {
            r := mload(add(data, 0x20))
            s := mload(add(data, 0x40))
            v := byte(0, mload(add(data, 0x60)))
            nonceType := byte(1, mload(add(data, 0x60)))
        }

        if (data.length > 66) {
            uint256 metadataLength = data.length - 66;
            metadata = new bytes(metadataLength);

            assembly {
                let metadataPtr := add(metadata, 0x20)
                let dataPtr := add(data, 0x62)
                let words := div(add(metadataLength, 31), 32)
                for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                    mstore(add(metadataPtr, mul(i, 0x20)), mload(add(dataPtr, mul(i, 0x20))))
                }
                mstore(metadata, metadataLength)
            }
        }
    }
}

contract ERC7518 is
    ERC1155,
    EIP712,
    AccessControlEnumerable,
    Pausable,
    ERC1155Burnable,
    ERC1155Supply,
    ERC1155AllowanceWrapper,
    FreezeAddress,
    RestrictTransfer,
    Payout,
    Nonce,
    TokenLock,
    IERC7518,
    ERC1155Permit,
    ReentrancyGuard
{
    // using ECDSA for bytes32;
    using byteOp for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); // Kept for compatibility
    bytes32 public constant PAYOUT_ROLE = keccak256("PAYOUT_ROLE");

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */
    address public compliTO;

    // Minimal ERC2771 style forwarder with runtime mutability
    address private _trustedForwarder;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */
    error InvalidCompliToSignature();
    error ZeroAddress();
    error RestrictedTransfer(address from, uint id);
    error InsufficientTransferableBalance(
        uint256 id,
        address account,
        uint256 transferableBalance,
        uint256 required
    );
    error AccessControlViolation();
    error InvalidNonceType(uint nonce);
    error InvalidArgLen();
    error FreezeAddressToForceTransfer(address account);

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */
    event ForcedTransfer(
        address indexed from,
        address indexed to,
        uint256 indexed id,
        uint256 amount,
        address operator
    );

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */
    constructor(
        string memory uridata,
        address compliance,
        address forwarder,
        address stablecoin,
        address owner
    ) ERC1155(uridata) EIP712("ERC7518", "1") {
        if (owner == address(0)) revert ZeroAddress();
        if (compliance == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(URI_SETTER_ROLE, owner);
        _grantRole(PAYOUT_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(MINTER_ROLE, owner);
        _grantRole(UPGRADER_ROLE, owner); // kept for compatibility

        _changePayoutAddress(stablecoin);
        compliTO = compliance;
        _setTrustedForwarder(forwarder);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  External                                  */
    /* -------------------------------------------------------------------------- */
    function mintBatch(
        address account,
        uint256[] memory id,
        uint256[] memory amount,
        bytes[] memory data
    ) external whenNotPaused onlyRole(MINTER_ROLE) {
        if (data.length != amount.length) revert InvalidArgLen();
        for (uint256 i = 0; i < data.length; i++) {
            mint(account, id[i], amount[i], data[i]);
        }
    }

    function setURI(string memory newuri) external onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function setForwarder(address forwarder) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTrustedForwarder(forwarder);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function payout(address to, uint256 amount)
        external
        onlyRole(PAYOUT_ROLE)
        nonReentrant
        returns (bool)
    {
        _payout(to, amount);
        return true;
    }

    function approve(address spender, uint id, uint256 amount) external returns (bool) {
        _approve(_msgSender(), spender, id, amount);
        return true;
    }

    function version() external pure returns (string memory) {
        return "3.0.0";
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Public                                   */
    /* -------------------------------------------------------------------------- */
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public whenNotPaused onlyRole(MINTER_ROLE) {
        canTransfer(address(0), account, id, amount, data);
        _increaseNonceBasedOnSignature(_msgSender(), data, id);
        _mint(account, id, amount, data);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override whenNotPaused {
        canTransfer(from, to, id, amount, data);
        require(
            from == _msgSender() || _spendAllowance(from, _msgSender(), amount, id),
            "ERC1155: caller is not token owner or approved"
        );
        _increaseNonceBasedOnSignature(from, data, id);
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        address sender = _msgSender();
        for (uint256 i = 0; i < ids.length; i++) {
            require(
                from == sender || _spendAllowance(from, sender, amounts[i], ids[i]),
                "ERC1155: caller is not token owner or approved"
            );
        }
        batchCanTransfer(from, to, ids, amounts, data);
        _increaseNonceBasedOnSignature(sender, data, ids[0]);
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function lockTokens(
        address account,
        uint id,
        uint amount,
        uint releaseTime
    ) public override onlyRole(MINTER_ROLE) returns (bool) {
        require(transferableBalance(account, id) >= amount, "Insufficient balance");
        _lockTokens(account, id, amount, releaseTime);
        return true;
    }

    function canTransfer(
        address from,
        address to,
        uint256 id,
        uint amount,
        bytes memory data
    ) public view override returns (bool) {
        if (from != address(0)) {
            require(transferableBalance(from, id) >= amount, "Insufficient transferable balance");
        }
        if (isRestricted(id)) revert RestrictedTransfer(_msgSender(), id);

        (uint8 nonceType, bytes32 r, bytes32 s, uint8 v, bytes memory metadata) = data.getSignatureComponent();

        uint256 nonce;
        if (nonceType == 1) {
            nonce = _globalNonces;
        } else if (nonceType == 2) {
            nonce = _userNonces[from][id];
        } else if (nonceType == 3) {
            nonce = _userNonces[to][id];
        } else {
            revert("Invalid nonce type");
        }

        bool status = ICompliTo(compliTO).verifySignature(
            from,
            to,
            id,
            amount,
            nonceType,
            nonce,
            metadata,
            v,
            r,
            s
        );
        if (!status) revert InvalidCompliToSignature();
        _checkFreezeAddress(to);
        _checkFreezeAddress(from);
        return true;
    }

    function transferableBalance(address account, uint id) public view returns (uint) {
        return balanceOf(account, id) - lockedBalanceOf(account, id);
    }

    function batchCanTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public view returns (bool) {
        for (uint i = 0; i < ids.length; i++) {
            if (from != address(0)) {
                require(transferableBalance(from, ids[i]) >= amounts[i], "Insufficient transferable balance");
            }
            if (isRestricted(ids[i])) revert RestrictedTransfer(from, ids[i]);
        }

        (uint8 nonceType, bytes32 r, bytes32 s, uint8 v, bytes memory metadata) = data.getSignatureComponent();
        uint256 nonce;
        if (nonceType == 1) {
            nonce = _globalNonces;
        } else {
            revert("Invalid nonce type");
        }

        bool status = ICompliTo(compliTO).batchVerifySignature(
            from,
            to,
            ids,
            amounts,
            nonceType,
            nonce,
            metadata,
            v,
            r,
            s
        );
        if (!status) revert InvalidCompliToSignature();
        _checkFreezeAddress(to);
        _checkFreezeAddress(from);
        return true;
    }

    function freeze(address account, bytes memory) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        _freeze(account);
        return true;
    }

    function unFreeze(address account, bytes memory) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        _unfreeze(account);
        return true;
    }

    function batchPayout(address[] calldata to, uint256[] calldata amount)
        public
        onlyRole(PAYOUT_ROLE)
        nonReentrant
        returns (bool)
    {
        if (to.length != amount.length) revert InvalidArgLen();
        for (uint256 i = 0; i < to.length; i++) {
            _payout(to[i], amount[i]);
        }
        return true;
    }

    function forceTokenUnlock(address account, uint id, uint lockId)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        _forceTokenUnlock(_msgSender(), account, id, lockId);
        return true;
    }

    function forceTransfer(
        address from,
        address to,
        uint id,
        uint amount,
        bytes memory data
    ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        if (!isFrozen(from)) revert FreezeAddressToForceTransfer(from);
        _checkFreezeAddress(to);
        _safeTransferFrom(from, to, id, amount, data);
        emit ForcedTransfer(from, to, id, amount, _msgSender());
        return true;
    }

    function restrictTransfer(uint id) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        _restrict(id);
        return true;
    }

    function removeRestriction(uint id) public returns (bool) {
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _removeRestriction(id);
        return true;
    }

    function changePayoutAddress(address newPayoutAddress)
        public
        onlyRole(PAYOUT_ROLE)
        returns (bool)
    {
        if (newPayoutAddress == address(0)) revert ZeroAddress();
        _changePayoutAddress(newPayoutAddress);
        return true;
    }

    function changeCompliToAddress(address newCompliToAddress)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        if (newCompliToAddress == address(0)) revert ZeroAddress();
        compliTO = newCompliToAddress;
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 id,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override whenNotPaused {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                id,
                value,
                _usePermitNonce(owner, id),
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }
        _approve(owner, spender, id, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControlEnumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal                                  */
    /* -------------------------------------------------------------------------- */
    function _increaseNonceBasedOnSignature(
        address sender,
        bytes memory data,
        uint id
    ) internal {
        uint8 nonceType;
        assembly {
            nonceType := byte(1, mload(add(data, 0x60)))
        }
        if (nonceType & 1 == 1) {
            _increaseGlobalNonce(sender);
        } else if (nonceType & 2 == 2) {
            _increaseUserNonce(sender, id);
        } else {
            revert InvalidNonceType(nonceType);
        }
    }

    function _payout(address to, uint256 amount) internal override {
        if (to == address(0)) revert ZeroAddress();
        _checkFreezeAddress(to);
        super._payout(to, amount);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /* ------------------------------- Meta Txns -------------------------------- */
    function isTrustedForwarder(address forwarder) public view returns (bool) {
        return forwarder != address(0) && forwarder == _trustedForwarder;
    }

    function _setTrustedForwarder(address forwarder) internal {
        _trustedForwarder = forwarder;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            sender = super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        }
        return super._msgData();
    }
}
