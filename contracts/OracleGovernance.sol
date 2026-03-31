// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title IVotesToken
 * @notice Interface for ERC20Votes-compatible token with historical checkpoints.
 */
interface IVotesToken {
    function totalSupply() external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);
}

/**
 * @title OracleGovernance
 * @notice Lightweight on-chain governance for OracleAI platform parameters.
 *         OAI token holders can create and vote on proposals.
 *
 * Proposal types: parameter changes, fee adjustments, treasury allocations.
 * Voting power = OAI delegated votes at snapshot block (ERC20Votes checkpoints).
 * Quorum = 1% of total supply at snapshot. Voting period = 3 days.
 */
contract OracleGovernance is AccessControl {
    IVotesToken public oaiToken;
    TimelockController public timelock;

    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 10_000 ether; // 10K OAI to propose
    uint256 public quorumBps = 100; // 1% of total supply

    enum ProposalState { Pending, Active, Defeated, Succeeded, Executed, Cancelled }

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool cancelled;
        bytes callData;    // optional: encoded function call for execution
        address target;    // optional: target contract for execution
        uint256 snapshotBlock; // block number for vote weight snapshot
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public voteWeight;
    mapping(uint256 => mapping(address => bool)) public voteDirection;

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime,
        uint256 snapshotBlock
    );
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);
    event ProposalCancelled(uint256 indexed id);
    event QuorumUpdated(uint256 oldBps, uint256 newBps);

    constructor(address _oaiToken, address payable _timelock) {
        require(_oaiToken != address(0), "Zero token");
        require(_timelock != address(0), "Zero timelock");
        oaiToken = IVotesToken(_oaiToken);
        timelock = TimelockController(_timelock);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ─── Propose ────────────────────────────────────────────────

    function propose(
        string calldata title,
        string calldata description,
        address target,
        bytes calldata callData
    ) external returns (uint256) {
        uint256 snapshot = block.number - 1;
        require(
            oaiToken.getPastVotes(msg.sender, snapshot) >= MIN_PROPOSAL_THRESHOLD,
            "Below proposal threshold"
        );
        require(bytes(title).length > 0 && bytes(title).length <= 200, "Invalid title");

        proposalCount++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;

        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            title: title,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: startTime,
            endTime: endTime,
            executed: false,
            cancelled: false,
            callData: callData,
            target: target,
            snapshotBlock: snapshot
        });

        emit ProposalCreated(proposalCount, msg.sender, title, startTime, endTime, snapshot);
        return proposalCount;
    }

    // ─── Vote ───────────────────────────────────────────────────

    function castVote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(p.id != 0, "Proposal not found");
        require(block.timestamp >= p.startTime && block.timestamp < p.endTime, "Voting closed");
        require(!p.cancelled, "Cancelled");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = oaiToken.getPastVotes(msg.sender, p.snapshotBlock);
        require(weight > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;
        voteWeight[proposalId][msg.sender] = weight;
        voteDirection[proposalId][msg.sender] = support;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    // ─── Execute ────────────────────────────────────────────────

    /**
     * @notice Queue a succeeded proposal into the timelock (48h delay).
     */
    function queue(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.id != 0, "Proposal not found");
        require(block.timestamp >= p.endTime, "Voting not ended");
        require(!p.executed, "Already executed");
        require(!p.cancelled, "Cancelled");
        require(state(proposalId) == ProposalState.Succeeded, "Not succeeded");

        if (p.target != address(0) && p.callData.length > 0) {
            bytes32 salt = keccak256(abi.encode(proposalId));
            timelock.schedule(p.target, 0, p.callData, bytes32(0), salt, timelock.getMinDelay());
        }
    }

    /**
     * @notice Execute a queued proposal after timelock delay has passed.
     */
    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.id != 0, "Proposal not found");
        require(!p.executed, "Already executed");
        require(!p.cancelled, "Cancelled");
        require(state(proposalId) == ProposalState.Succeeded, "Not succeeded");

        p.executed = true;

        if (p.target != address(0) && p.callData.length > 0) {
            bytes32 salt = keccak256(abi.encode(proposalId));
            timelock.execute(p.target, 0, p.callData, bytes32(0), salt);
        }

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.id != 0, "Proposal not found");
        require(
            msg.sender == p.proposer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(!p.executed, "Already executed");

        p.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    // ─── View ───────────────────────────────────────────────────

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal memory p = proposals[proposalId];
        if (p.id == 0) return ProposalState.Pending;
        if (p.cancelled) return ProposalState.Cancelled;
        if (p.executed) return ProposalState.Executed;
        if (block.timestamp < p.endTime) return ProposalState.Active;

        // Check quorum: forVotes + againstVotes >= quorum % of total supply at snapshot
        uint256 totalVotes = p.forVotes + p.againstVotes;
        uint256 quorum = (oaiToken.getPastTotalSupply(p.snapshotBlock) * quorumBps) / 10000;

        if (totalVotes < quorum) return ProposalState.Defeated;
        if (p.forVotes > p.againstVotes) return ProposalState.Succeeded;
        return ProposalState.Defeated;
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getVoteInfo(uint256 proposalId, address voter)
        external
        view
        returns (bool voted, uint256 weight, bool support)
    {
        voted = hasVoted[proposalId][voter];
        weight = voteWeight[proposalId][voter];
        support = voteDirection[proposalId][voter];
    }

    // ─── Admin ──────────────────────────────────────────────────

    function setQuorum(uint256 newBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newBps > 0 && newBps <= 5000, "Invalid quorum"); // 0.01% to 50%
        uint256 oldBps = quorumBps;
        quorumBps = newBps;
        emit QuorumUpdated(oldBps, newBps);
    }
}
