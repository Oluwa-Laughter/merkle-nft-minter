# Merkle NFT Minter

An ERC-721 minting contract with an allowlist sale, a public sale, and
owner-controlled administration. The allowlist is represented by a Merkle
root, so eligible wallets and their mint limits do not need to be stored
on-chain individually.

## Features

- Three explicit phases: `Inactive`, `Allowlist`, and `Public`
- Per-wallet allowlist allowances with support for multiple claims
- Public per-wallet mint limit
- Exact ETH payment for every mint
- Maximum supply enforcement
- Pause/unpause and owner withdrawal controls
- Token IDs starting at `1`
- Metadata formatted as `<baseURI><tokenId>.json`

## Minting Flow

```text
Inactive -> Allowlist -> Public
```

The owner changes phases manually. Minting is unavailable while the
contract is `Inactive` or paused.

### Allowlist mint

An allowlist leaf commits to both the wallet and its maximum allowance:

```solidity
keccak256(abi.encodePacked(wallet, maxAllowance))
```

The proof must be built with sorted hash pairs. At mint time, the contract
checks the sender, allowance, proof, exact payment, and remaining supply.
Consumed allowance is tracked per wallet, so an allowance of `3` can be
claimed as `1 + 2`, but not as a fourth NFT.

### Public mint

Public mints do not require a proof. The contract checks the sender's
public mint total against `publicWalletLimit`, requires exact payment, and
enforces `maxSupply`.

## Constructor

The contract is deployed with:

| Parameter           | Description                                             |
| ------------------- | ------------------------------------------------------- |
| `name`              | ERC-721 collection name                                 |
| `symbol`            | ERC-721 collection symbol                               |
| `price`             | Price per NFT in wei                                    |
| `maxSupply`         | Maximum number of NFTs that can be minted               |
| `publicWalletLimit` | Maximum public mints per wallet                         |
| `baseURI`           | Prefix for token metadata, such as `ipfs://collection/` |

The included deployment script uses `Merkle NFT`, `MNFT`, `0.01 ether`,
`100`, `5`, and `ipfs://collection/`.

## Project Layout

```text
src/MerkleNFTMinter.sol             Contract implementation
script/DeployMerkleNFTMinter.s.sol  Deployment script
test/MerkleNFTMinterTest.t.sol      Focused unit tests
foundry.toml                        Foundry configuration
```

## Quick Start

Install [Foundry](https://book.getfoundry.sh/getting-started/installation),
then install dependencies and run the checks:

```shell
forge install
forge build
forge test
forge fmt --check
```

Run the local chain with:

```shell
anvil
```

Deploy using the included script. `MERKLE_ROOT` must be a `bytes32` value
generated from the allowlist tree:

```shell
export MERKLE_ROOT=0x<merkle-root>
forge script script/DeployMerkleNFTMinter.s.sol:DeployMerkleNFTMinter \
    --rpc-url <rpc-url> \
    --private-key <private-key> \
    --broadcast
```

After deployment, move the contract from `Inactive` to `Allowlist` or
`Public` with `setPhase`.

## Owner Operations

The deployer becomes the immutable owner and can:

- update the Merkle root with `setMerkleRoot`
- change the sale phase with `setPhase`
- update metadata with `setBaseURI`
- pause or resume minting with `pause` and `unpause`
- withdraw collected ETH with `withdraw`

## ERC-721 Support

The contract includes ownership, balances, approvals, operator approvals,
transfers, and `tokenURI`. It emits the standard ERC-721 transfer and
approval events used by compatible tooling.

## Verification

The test suite covers valid and invalid proofs, allowance changes, repeated
claims, exact payment, phase restrictions, supply exhaustion, and phase
transitions.

Useful commands:

```shell
forge test -vv
forge snapshot
cast <subcommand>
```
