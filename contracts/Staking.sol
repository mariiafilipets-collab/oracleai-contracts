// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Staking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public oaiToken;

    uint256 public constant UNSTAKE_COOLDOWN = 7 days;

    // ─── Staking Tiers ──────────────────────────────────────────────
    //  Bronze:   100 - 999 OAI    → +10% points, +5% referral
    //  Silver:   1,000 - 9,999    → +20% points, +10% referral
    //  Gold:     10,000 - 99,999  → +35% points, +15% referral
    //  Diamond:  100,000+         → +50% points, +20% referral

    uint256 public constant BRONZE_MIN   = 100 ether;
    uint256 public constant SILVER_MIN   = 1_000 ether;
    uint256 public constant GOLD_MIN     = 10_000 ether;
    uint256 public constant DIAMOND_MIN  = 100_000 ether;

    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 unstakeRequestedAt;
        uint256 unstakeAmount;
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;
    uint256 public totalStakers;
    mapping(address => bool) private _hasStaked;

    // ─── BNB Reward Distribution (Synthetix-style) ───────────────────
    uint256 public rewardRate;           // BNB per second
    uint256 public rewardPerTokenStored; // accumulated reward per token (scaled 1e18)
    uint256 public lastRewardUpdateTime;
    uint256 public rewardPeriodEnd;
    uint256 public constant REWARD_DURATION = 7 days;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public pendingRewards;

    uint256 public totalRewardsDistributed;

    event Staked(address indexed user, uint256 amount, string tier);
    event UnstakeRequested(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardAdded(uint256 amount, uint256 duration);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _oaiToken) Ownable(msg.sender) {
        oaiToken = IERC20(_oaiToken);
    }

    // ─── Reward Modifier ─────────────────────────────────────────────
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastRewardUpdateTime = lastApplicableTime();
        if (account != address(0)) {
            pendingRewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // ─── Reward View Functions ───────────────────────────────────────
    function lastApplicableTime() public view returns (uint256) {
        return block.timestamp < rewardPeriodEnd ? block.timestamp : rewardPeriodEnd;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored +
            ((lastApplicableTime() - lastRewardUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (stakes[account].amount * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18
            + pendingRewards[account];
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Zero amount");
        oaiToken.safeTransferFrom(msg.sender, address(this), amount);

        if (!_hasStaked[msg.sender]) {
            _hasStaked[msg.sender] = true;
            totalStakers++;
        }

        stakes[msg.sender].amount += amount;
        stakes[msg.sender].stakedAt = block.timestamp;
        totalStaked += amount;

        emit Staked(msg.sender, amount, getTierName(msg.sender));
    }

    function requestUnstake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Zero amount");
        require(stakes[msg.sender].amount >= amount, "Insufficient stake");
        stakes[msg.sender].unstakeRequestedAt = block.timestamp;
        stakes[msg.sender].unstakeAmount = amount;
        emit UnstakeRequested(msg.sender, amount);
    }

    function unstake() external nonReentrant updateReward(msg.sender) {
        StakeInfo storage info = stakes[msg.sender];
        require(info.unstakeAmount > 0, "No unstake pending");
        require(block.timestamp >= info.unstakeRequestedAt + UNSTAKE_COOLDOWN, "Cooldown active");

        uint256 amount = info.unstakeAmount;
        info.amount -= amount;
        info.unstakeAmount = 0;
        info.unstakeRequestedAt = 0;
        totalStaked -= amount;

        // Decrement staker count if fully unstaked (LOW-03)
        if (info.amount == 0) {
            totalStakers--;
        }

        oaiToken.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function getPointsBoost(address user) external view returns (uint256) {
        uint256 amt = stakes[user].amount;
        if (amt >= DIAMOND_MIN) return 5000; // +50%
        if (amt >= GOLD_MIN)    return 3500; // +35%
        if (amt >= SILVER_MIN)  return 2000; // +20%
        if (amt >= BRONZE_MIN)  return 1000; // +10%
        return 0;
    }

    function getReferralBoost(address user) external view returns (uint256) {
        uint256 amt = stakes[user].amount;
        if (amt >= DIAMOND_MIN) return 2000; // +20%
        if (amt >= GOLD_MIN)    return 1500; // +15%
        if (amt >= SILVER_MIN)  return 1000; // +10%
        if (amt >= BRONZE_MIN)  return 500;  // +5%
        return 0;
    }

    function getTier(address user) external view returns (uint8) {
        uint256 amt = stakes[user].amount;
        if (amt >= DIAMOND_MIN) return 4;
        if (amt >= GOLD_MIN)    return 3;
        if (amt >= SILVER_MIN)  return 2;
        if (amt >= BRONZE_MIN)  return 1;
        return 0;
    }

    function getTierName(address user) public view returns (string memory) {
        uint256 amt = stakes[user].amount;
        if (amt >= DIAMOND_MIN) return "Diamond";
        if (amt >= GOLD_MIN)    return "Gold";
        if (amt >= SILVER_MIN)  return "Silver";
        if (amt >= BRONZE_MIN)  return "Bronze";
        return "None";
    }

    function getStakeInfo(address user) external view returns (StakeInfo memory) {
        return stakes[user];
    }

    // ─── BNB Reward Functions ────────────────────────────────────────

    /// @notice Called when BNB rewards arrive (from CheckIn/Prediction fee splits)
    function notifyRewardAmount() external payable onlyOwner updateReward(address(0)) {
        require(msg.value > 0, "Zero reward");
        if (block.timestamp >= rewardPeriodEnd) {
            rewardRate = msg.value / REWARD_DURATION;
        } else {
            uint256 remaining = rewardPeriodEnd - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (msg.value + leftover) / REWARD_DURATION;
        }
        require(rewardRate > 0, "Rate too low");
        lastRewardUpdateTime = block.timestamp;
        rewardPeriodEnd = block.timestamp + REWARD_DURATION;
        emit RewardAdded(msg.value, REWARD_DURATION);
    }

    function claimRewards() external nonReentrant updateReward(msg.sender) {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "No rewards");
        pendingRewards[msg.sender] = 0;
        totalRewardsDistributed += reward;
        (bool ok, ) = payable(msg.sender).call{value: reward}("");
        require(ok, "Reward transfer failed");
        emit RewardClaimed(msg.sender, reward);
    }

    receive() external payable {}
}
