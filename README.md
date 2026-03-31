# OracleAI Predict — Smart Contracts

AI-powered decentralized prediction market on BNB Smart Chain.

## Overview

OracleAI Predict is a prediction market where users vote YES/NO on real-world events across Sports, Crypto, Economy, Politics, and Climate. An autonomous AI agent generates and resolves events using real-time data. Users who predict correctly AND beat the AI earn 2x rewards.

## Deployed Contracts (BSC Mainnet — Chain 56)

| Contract | Address | Description |
|----------|---------|-------------|
| **Prediction** | [`0xD22e115607f1a42a659bAb49683E055f71851E42`](https://bscscan.com/address/0xD22e115607f1a42a659bAb49683E055f71851E42) | Core voting: YES/NO predictions, fee split, Beat AI rewards |
| **Points** | [`0x00Ede3194965A71d696F927583ce94AA5D9aa99C`](https://bscscan.com/address/0x00Ede3194965A71d696F927583ce94AA5D9aa99C) | Points tracking, leaderboard |
| **CheckIn** | [`0x6ffB91eb7AE7D041296C63D9cf5DDEa90236249F`](https://bscscan.com/address/0x6ffB91eb7AE7D041296C63D9cf5DDEa90236249F) | Daily check-in with streak bonuses |
| **Referral** | [`0x7db3CAC0548e41fb990c0B511de561ebd3abaDCc`](https://bscscan.com/address/0x7db3CAC0548e41fb990c0B511de561ebd3abaDCc) | 6-level referral system |
| **PrizePool** | [`0xABf45860CfaE1c95B3A32a5853c1A2bAAAE2089A`](https://bscscan.com/address/0xABf45860CfaE1c95B3A32a5853c1A2bAAAE2089A) | Season-aware prize pool with Merkle claims |
| **QuestClaim** | [`0x74B0D8f130e176cE4ae72527b02068D557e85811`](https://bscscan.com/address/0x74B0D8f130e176cE4ae72527b02068D557e85811) | On-chain quest claims with EIP-712 signatures |
| **Staking** | [`0x64CcE996c9285e15ff17e3924971AD78A068F39F`](https://bscscan.com/address/0x64CcE996c9285e15ff17e3924971AD78A068F39F) | OAI staking with 4 tiers |
| **InsurancePool** | [`0x4fc5bCA3b8Ea3c90B630411410f7a78FA8828353`](https://bscscan.com/address/0x4fc5bCA3b8Ea3c90B630411410f7a78FA8828353) | Insurance pool for risk management |
| **OAI Token** | TGE Q4 2026 | ERC-20, 1B total supply, deflationary |

## Architecture

### Fee Split (100% of voting fees)

| Recipient | Share |
|-----------|-------|
| Prize Pool (seasonal) | 65% |
| Referral Tree | 13% |
| Treasury | 12% |
| Buyback & Burn | 5% |
| Staking Rewards | 3% |
| Insurance | 2% |

### Vote Points (on-chain)

| Outcome | Base Points | Basic (1x) | Pro (3x) | Whale (10x) |
|---------|------------|------------|----------|-------------|
| Correct (AI also correct) | 50 | 50 | 150 | 500 |
| Beat AI (AI was wrong) | 50 x 2 | 100 | 300 | 1000 |
| Wrong | 0 | 0 | 0 | 0 |

### Staking Tiers

| Tier | OAI Required | Points Boost | Referral Boost |
|------|-------------|-------------|----------------|
| Bronze | 100 - 999 | +10% | +5% |
| Silver | 1,000 - 9,999 | +20% | +10% |
| Gold | 10,000 - 99,999 | +35% | +15% |
| Diamond | 100,000+ | +50% | +20% |

## Contract Files

```
contracts/
  Prediction.sol         — Core prediction voting and resolution
  Points.sol             — Points system and leaderboard
  CheckIn.sol            — Daily check-in with streak bonuses
  Referral.sol           — 6-level referral tree (5%/3%/2%/1.5%/1%/0.5%)
  PrizePool.sol          — Base prize pool
  PrizePoolV2.sol        — Enhanced prize pool
  PrizePoolV3.sol        — Season-aware prize pool with Merkle claims
  QuestClaim.sol         — On-chain quest claiming (EIP-712)
  Staking.sol            — OAI token staking (4 tiers)
  InsurancePool.sol      — Insurance fund (25% max payout)
  OAIToken.sol           — ERC-20 token (1B supply, deflationary)
  OAIVesting.sol         — Token vesting schedules
  OracleGovernance.sol   — On-chain governance voting
  OracleTimelock.sol     — 48-hour timelock for governance
  PredictionNFT.sol      — Achievement NFTs
  VRFBonusDistributor.sol — Chainlink VRF bonus distribution
```

## Tech Stack

- **Solidity** 0.8.24
- **Hardhat** with optimizer (200 runs) + viaIR
- **OpenZeppelin** Contracts (AccessControl, ReentrancyGuard, ERC20)
- **Chainlink** VRF v2
- **BNB Smart Chain** (Mainnet Chain 56)

## Setup

```bash
npm install
npx hardhat compile
npx hardhat test
```

## Links

- **Website:** [oraclepredict.ai](https://www.oraclepredict.ai)
- **App:** [oracleai-predict.app](https://oracleai-predict.app)
- **Twitter:** [@oraclepredictai](https://x.com/oraclepredictai)
- **Telegram:** [OracleAiPredict](https://t.me/OracleAiPredict)
- **Discord:** [Join](https://discord.com/invite/hKPfspcKz)

## License

MIT
