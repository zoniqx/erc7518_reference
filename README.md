# ERC‑7518 (DyCIST) Reference Implementation

##  What Is ERC‑7518?

ERC‑7518 (DyCIST) is a proposed security token standard that builds on **ERC‑1155**, enabling **semi-fungible partitions**, dynamic compliance, and **cross‑chain interoperability**. Each `tokenId` acts as a distinct partition—such as tranche, class, or share type—with its own rights and rules. The standard also defines features like token locks, forced transfers, freezing, payouts, wrapping, and compliance hooks. ([eips.ethereum.org](https://eips.ethereum.org/EIPS/eip-7518))

### Key Concepts from the EIP

- **Partitions via `tokenId`**: Enables semi-fungible tokens with partition‑specific logic.  
- **Compliance Hooks**: Methods like `canTransfer`, `lockTokens`, `forceTransfer`, and `freeze` provide dynamic and enforceable rules.  
- **Payouts & Batch Payouts**: Built-in functions for token‑holder distributions.  
- **Interoperability**: Wrapping and unwrapping tokens, enabling cross‑chain or cross‑standard compatibility.  
- **Built on ERC‑1155 + ERC‑165**: Ensures backward compatibility and easy integration with wallets and dApps.  

## Project Structure

```
erc‑7518‑foundry/
├── src/
│   ├── ERC7518.sol              # Core implementation
│   └── interfaces/
│       └── IERC7518.sol         # Interface contract
├── test/
│   └── ERC7518.t.sol            # Basic Foundry tests
├── script/
│   └── Deploy.s.sol             # Simple deployment script
├── lib/                         # Dependencies (e.g., OZ contracts)
├── foundry.toml
├── README.md
└── LICENSE
```

##  Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) installed (`forge`, `cast`).
- Solidity ≥ 0.8.x.

### Installation

```bash
forge init erc‑7518‑foundry
cd erc‑7518‑foundry
forge install OpenZeppelin/openzeppelin-contracts
```

### Building & Testing

```bash
forge build
forge test
```

### Deployment

```bash
forge script script/Deploy.s.sol:DeployERC7518 --broadcast --rpc-url <RPC_URL>
```

Customize the script to deploy with a URI or initial partitions as needed.

##  Core Features (Minimal Reference)

- Partition-based semi-fungible token logic via ERC‑1155.
- `transferWithData` or variations ready for compliance hooks.
- Stubbed placeholders for:
  - `canTransfer`
  - `lockTokens` / `unlockToken`
  - `freeze` / `unfreeze`
  - `forceTransfer`
  - `payout()` / `batchPayout()`
  - `wrapToken` / `unwrapToken`

These are intentionally kept simple—meant for educational clarity and future extension.

##  Example Use Cases

- **Fractional real estate classes**: Define separate tranches (e.g., common vs. preferred) as partitions.
- **Tranche-based finance**: Different risk/return tiers represented by partition-specific token IDs.
- **Cross-chain compliant RWAs**: Tokens retain compliance state while moving across chains.

##  Extension Guide

To move from the minimal reference to a production-grade implementation:

1. **Implement compliance logic**: Add `canTransfer(...)` checks using off-chain vouchers or on-chain registries.
2. **Add recovery and lock features**: Support token recovery via `forceTransfer`, and vesting via `lockTokens`.
3. **Support freezing**: Allow `freeze()` and `unfreeze()` on accounts or partitions.
4. **Enable payouts**: Safely distribute payouts using `payout()` and `batchPayout()`.
5. **Incorporate interoperability**: Use `wrapToken()` and `unwrapToken()` for cross-chain or cross-standard compatibility.
6. **Audit, document, license**: Add comments, documentation, and choose a suitable open-source license (e.g., MIT).

## License

This project is released under the **GPL-3.0 License**.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```


