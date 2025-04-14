# 🧠 PreidxGameContract

**Smart contract for committing and resolving encrypted vote-based prediction games using ETH, USDT, or any ERC20 token.**

This contract enables secure vote commitments with asset staking and includes full support for encrypted vote submissions, batch withdrawals, and cross-token reward distribution — all owned and controlled by the platform owner.

---

## 📜 Overview

`PreidxGameContract` is a modular and gas-efficient contract that facilitates encrypted vote commitments with optional staking in ETH, USDT, or any ERC20 token. Designed for on-chain PvP prediction platforms, it supports the following:

- Encrypted vote submission with commitment data
- Real-time ETH handling and balance tracking
- Secure vote count and withdrawal protection
- Batch reward distribution across multiple users
- Owner-controlled fund withdrawal with reentrancy protection

---

## ⚙️ Core Features

### ✅ Encrypted Voting with Staking
- Users submit an encrypted vote along with ETH value or asset stake.
- Prevents vote front-running and ensures commitment integrity.

### ✅ Multi-Asset Support
- ETH
- USDT (via `IERC20Upgradeable`)
- Any ERC20 token

### ✅ Vote Tracking and Commitment Storage
- Stores commitments (`commitment`, `quantity`, `asset`) per voteId and address.
- Tracks:
  - If a user has voted
  - If a user has withdrawn
  - Total vote count per voteId

### ✅ Batch Withdrawal Functions
- Supports bulk reward withdrawals in:
  - ETH
  - USDT (Upgradeable)
  - ERC20
- Includes:
  - Failure tracking for partial failures
  - Vote validation before withdrawal
  - `hasWithdrawn` flag for double-withdraw prevention

---

## 📦 Contract Structure

### Structs

```solidity
struct TokenAmount {
    address token;
    uint256 amount;
}

struct VoteCommitment {
    bytes commitment;
    bytes quantity;
    bytes asset;
}
