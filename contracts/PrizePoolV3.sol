// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title PrizePoolV3 — Season-Aware Prize Pool
 * @notice Tracks BNB fees per season. Each season has its own balance.
 *         Claims from past seasons don't affect current season's displayed pool.
 */
contract PrizePoolV3 is AccessControl, ReentrancyGuard {
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    struct Epoch {
        bytes32 merkleRoot;
        uint256 totalAllocation;
        uint256 claimed;
        uint256 startedAt;
        uint256 seasonId;
    }

    uint256 public currentSeasonId;
    uint256 public currentEpoch;
    uint256 public totalDistributed;
    uint256 public reservedFunds;

    mapping(uint256 => uint256) public seasonBalance;
    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;

    event PrizeReceived(address indexed from, uint256 amount, uint256 seasonId);
    event SeasonStarted(uint256 indexed seasonId);
    event EpochStarted(uint256 indexed epoch, bytes32 merkleRoot, uint256 totalAllocation, uint256 indexed seasonId);
    event PrizeClaimed(uint256 indexed epoch, uint256 indexed index, address indexed account, uint256 amount);
    event EmergencyWithdraw(address to, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        currentSeasonId = 1;
        emit SeasonStarted(1);
    }

    /// @notice Accept BNB fees — tagged to current season
    receive() external payable {
        seasonBalance[currentSeasonId] += msg.value;
        emit PrizeReceived(msg.sender, msg.value, currentSeasonId);
    }

    /// @notice Start a new season. Only DISTRIBUTOR_ROLE.
    function startNewSeason() external onlyRole(DISTRIBUTOR_ROLE) {
        currentSeasonId += 1;
        emit SeasonStarted(currentSeasonId);
    }

    /// @notice Create a new epoch (Merkle distribution) from current season's balance
    function startEpoch(bytes32 merkleRoot, uint256 totalAllocation) external onlyRole(DISTRIBUTOR_ROLE) {
        require(merkleRoot != bytes32(0), "Empty root");
        require(totalAllocation > 0, "Bad allocation");
        require(seasonBalance[currentSeasonId] >= totalAllocation, "Insufficient season balance");

        seasonBalance[currentSeasonId] -= totalAllocation;
        reservedFunds += totalAllocation;

        currentEpoch += 1;
        epochs[currentEpoch] = Epoch({
            merkleRoot: merkleRoot,
            totalAllocation: totalAllocation,
            claimed: 0,
            startedAt: block.timestamp,
            seasonId: currentSeasonId
        });

        emit EpochStarted(currentEpoch, merkleRoot, totalAllocation, currentSeasonId);
    }

    /// @notice Claim prize using Merkle proof
    function claim(
        uint256 epoch,
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        require(account == msg.sender, "Not claimant");
        require(!_isClaimed(epoch, index), "Already claimed");

        Epoch storage e = epochs[epoch];
        require(e.merkleRoot != bytes32(0), "Epoch missing");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(index, account, amount))));
        require(MerkleProof.verify(merkleProof, e.merkleRoot, leaf), "Bad proof");

        _setClaimed(epoch, index);
        require(e.claimed + amount <= e.totalAllocation, "Allocation exceeded");
        e.claimed += amount;
        totalDistributed += amount;
        reservedFunds -= amount;

        (bool ok, ) = account.call{value: amount}("");
        require(ok, "Transfer failed");

        emit PrizeClaimed(epoch, index, account, amount);
    }

    /// @notice Get current season's available balance (what frontend displays)
    function getSeasonBalance() external view returns (uint256) {
        return seasonBalance[currentSeasonId];
    }

    /// @notice Get any season's balance
    function getSeasonBalanceOf(uint256 seasonId) external view returns (uint256) {
        return seasonBalance[seasonId];
    }

    /// @notice Free balance = total balance - reserved (backward compat)
    function freeBalance() external view returns (uint256) {
        return address(this).balance - reservedFunds;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function isClaimed(uint256 epoch, uint256 index) external view returns (bool) {
        return _isClaimed(epoch, index);
    }

    function _isClaimed(uint256 epoch, uint256 index) internal view returns (bool) {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        uint256 word = claimedBitMap[epoch][wordIndex];
        uint256 mask = (1 << bitIndex);
        return word & mask == mask;
    }

    function _setClaimed(uint256 epoch, uint256 index) internal {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        claimedBitMap[epoch][wordIndex] = claimedBitMap[epoch][wordIndex] | (1 << bitIndex);
    }

    function emergencyWithdraw(address to) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(to != address(0), "Zero recipient");
        uint256 free = address(this).balance - reservedFunds;
        require(free > 0, "Nothing to withdraw");
        // Reset season balance to avoid desync after withdrawal
        seasonBalance[currentSeasonId] = 0;
        (bool ok, ) = to.call{value: free}("");
        require(ok, "Transfer failed");
        emit EmergencyWithdraw(to, free);
    }
}
