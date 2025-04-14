# 🧠 PreidxGameContract

**Smart contract for managing encrypted PvP game participation with staking in ETH, USDT, or any ERC20 token.**

`PreidxGameContract` powers secure and scalable prediction games where users join games by submitting encrypted commitments with asset stakes. It enables automated reward distribution, batch withdrawals, and robust tracking — all under secure ownership.

---

## 📜 Overview

`PreidxGameContract` is a modular and gas-efficient smart contract for on-chain PvP prediction games. It supports encrypted game joins, real-time staking in multiple assets, and owner-controlled payout logic.

Core capabilities include:

- Encrypted game participation with data commitments
- ETH, USDT, and ERC20 staking support
- Game player tracking and join validation
- Batch reward distribution
- Withdrawal and security protection via ReentrancyGuard

---

## ⚙️ Core Features

### ✅ Encrypted Game Participation
- Players submit encrypted data (`commitment`, `quantity`, `asset`) to join a game.
- Prevents front-running and protects strategy using commitment encryption.

### ✅ Multi-Asset Staking
- ETH (native)
- USDT via `IERC20Upgradeable`
- Any ERC20 token

### ✅ Game Participation Tracking
- Tracks per `gameId` and player:
  - Has the player joined?
  - Has the player already withdrawn?
  - How many players joined this game?

### ✅ Batch Reward Withdrawals
- Owner can distribute winnings across multiple players in a single transaction.
- Supports:
  - ETH batch payout
  - USDT batch payout
  - Generic ERC20 token batch payout
- Each batch withdrawal tracks failures to avoid reverts on individual issues.

---

### 💰 Predix Contract Ecosystem
- Support for ERC20 tokens including community coins.
- Contract: 0x7e42a7D7E5bDBe136091Fa89BbFbae98B891bE1c
- txHash : https://sepolia.basescan.org/tx/0x81b13d4edb6716a05f68a6667e2fe063e955d0a51c3eff803e2f9cd64b5cc0f6

---

## 📦 Contract Structure

### Structs

```solidity
struct TokenAmount {
    address token;
    uint256 amount;
}

struct GameCommitment {
    bytes commitment;
    bytes quantity;
    bytes asset;
}
