# OracleAI Predict

AI-powered decentralized prediction market built on **BNB Smart Chain (BSC)**. Users predict real-world events, compete against an autonomous AI oracle, and earn BNB rewards through seasonal prize pools.

## Technology Stack

- **Blockchain**: BNB Smart Chain (BSC Mainnet, Chain ID: 56)
- **Smart Contracts**: Solidity ^0.8.24
- **Frontend**: Next.js 14 + React 18 + wagmi + ethers.js
- **Development**: Hardhat (optimizer 200 runs, viaIR), OpenZeppelin Contracts
- **Oracle**: Chainlink VRF v2
- **AI Agent**: OpenClaw (autonomous event generation & resolution)

## Supported Networks

- **BNB Smart Chain Mainnet** (Chain ID: 56) — Production deployment

## Contract Addresses

### BNB Smart Chain Mainnet (Chain 56)

| Contract | Address | Description |
|----------|---------|-------------|
| **PredictionEvent** | [`0xD22e115607f1a42a659bAb49683E055f71851E42`](https://bscscan.com/address/0xD22e115607f1a42a659bAb49683E055f71851E42) | Event creation, voting, resolution, fee split, Beat AI rewards |
| **Points** | [`0x00Ede3194965A71d696F927583ce94AA5D9aa99C`](https://bscscan.com/address/0x00Ede3194965A71d696F927583ce94AA5D9aa99C) | On-chain points tracking, seasonal leaderboard |
| **CheckIn** | [`0x6ffB91eb7AE7D041296C63D9cf5DDEa90236249F`](https://bscscan.com/address/0x6ffB91eb7AE7D041296C63D9cf5DDEa90236249F) | Daily check-in with fee split and streak bonuses |
| **Referral** | [`0xA6367BCda89a84E3FAB998E9bc275ffAA148f742`](https://bscscan.com/address/0xA6367BCda89a84E3FAB998E9bc275ffAA148f742) | 6-level referral tree |
| **PrizePool** | [`0xABf45860CfaE1c95B3A32a5853c1A2bAAAE2089A`](https://bscscan.com/address/0xABf45860CfaE1c95B3A32a5853c1A2bAAAE2089A) | Season prizes with Merkle claims |
| **QuestClaim** | [`0x74B0D8f130e176cE4ae72527b02068D557e85811`](https://bscscan.com/address/0x74B0D8f130e176cE4ae72527b02068D557e85811) | EIP-712 signed quest rewards |
| **Staking** | [`0x64CcE996c9285e15ff17e3924971AD78A068F39F`](https://bscscan.com/address/0x64CcE996c9285e15ff17e3924971AD78A068F39F) | OAI staking with tier boosts |
| **InsurancePool** | [`0x4fc5bCA3b8Ea3c90B630411410f7a78FA8828353`](https://bscscan.com/address/0x4fc5bCA3b8Ea3c90B630411410f7a78FA8828353) | Platform insurance fund |
| **OAI Token** | TGE Q4 2026 | ERC-20, 1B total supply, deflationary |

All contracts are **verified on BscScan**.

## Features

- **AI-Powered Predictions on BNB Chain**: Autonomous AI agent generates and resolves real-world events across Sports, Crypto, Economy, Politics, and Climate — all settled on BSC
- **Beat the AI Mechanic**: Unique human-vs-AI competition — earn 2x points when your prediction beats the AI oracle, fully calculated on-chain
- **Gas-Efficient Design for BSC**: Micro-predictions from 0.00015 BNB (~$0.10) made viable by BSC's low gas fees, with optimized contract interactions
- **On-Chain Fee Distribution**: Automatic BNB fee splitting — 65% to seasonal prize pool, 13% referrals, 12% treasury, 5% burn, 3% staking, 2% insurance
- **Seasonal Prize Pools**: 2-week competitive seasons with Merkle-tree BNB prize claims, fully on-chain season isolation via PrizePool contract
- **6-Level Referral System**: On-chain referral tree with cascading BNB rewards (5%/3%/2%/1.5%/1%/0.5%)
- **Security**: AccessControl roles, ReentrancyGuard on all BNB transfers, 48-hour governance timelock, insurance pool with 25% max payout cap

## Architecture

### Fee Split (100% of BNB voting fees, on-chain)

| Recipient | Share |
|-----------|-------|
| Prize Pool (seasonal) | 65% |
| Referral Tree | 13% |
| Treasury | 12% |
| Buyback & Burn | 5% |
| Staking Rewards | 3% |
| Insurance | 2% |

### Vote Points (calculated on-chain in Prediction.sol)

| Outcome | Base Points | Basic (1x) | Pro (3x) | Whale (10x) |
|---------|------------|------------|----------|-------------|
| Correct (AI also correct) | 50 | 50 | 150 | 500 |
| Beat AI (AI was wrong) | 50 x 2 | 100 | 300 | 1000 |
| Wrong | 0 | 0 | 0 | 0 |

### Staking Tiers (on-chain in Staking.sol)

| Tier | OAI Required | Points Boost | Referral Boost |
|------|-------------|-------------|----------------|
| Bronze | 100 - 999 | +10% | +5% |
| Silver | 1,000 - 9,999 | +20% | +10% |
| Gold | 10,000 - 99,999 | +35% | +15% |
| Diamond | 100,000+ | +50% | +20% |

## Contract Files

All 8 contracts are deployed and verified on **BNB Smart Chain Mainnet (Chain 56)**.

```
contracts/
  Prediction.sol    — PredictionEvent: creation, voting, resolution, fee split, Beat AI
  Points.sol        — Points system and seasonal leaderboard
  CheckIn.sol       — Daily check-in with streak bonuses (up to +50%)
  Referral.sol      — 6-level referral tree with BNB cascading rewards
  PrizePool.sol     — Season-aware BNB prize pool with Merkle claims
  QuestClaim.sol    — On-chain quest claiming (EIP-712 signatures)
  Staking.sol       — OAI token staking (4 tiers: Bronze/Silver/Gold/Diamond)
  InsurancePool.sol — Insurance fund (25% max payout cap)
```

## BSC Network Configuration

```javascript
// hardhat.config.js
networks: {
  bscMainnet: {
    url: "https://bsc-dataseed1.bnbchain.org:8545",
    chainId: 56,
    gasPrice: 3000000000, // 3 gwei — optimized for BSC
  },
}
```

## Setup

```bash
npm install
npx hardhat compile
npx hardhat test
```

## Deploy to BSC Mainnet

```bash
npx hardhat run scripts/deploy.js --network bscMainnet

# Verify on BscScan
npx hardhat verify --network bscMainnet <CONTRACT_ADDRESS>
```

## Links

- **Website:** [oraclepredict.ai](https://www.oraclepredict.ai)
- **BscScan:** [View Contracts](https://bscscan.com/address/0xD22e115607f1a42a659bAb49683E055f71851E42)
- **Twitter:** [@oraclepredictai](https://x.com/oraclepredictai)
- **Telegram:** [OracleAiPredict](https://t.me/OracleAiPredict)
- **Discord:** [Join](https://discord.com/invite/hKPfspcKz)

## License

MIT
