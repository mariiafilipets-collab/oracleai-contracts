// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract OAIToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;

    // ─── Token Allocation (1B OAI) ──────────────────────────────────
    //  25%  Community Airdrop    — 250M — minted via mintAirdrop() based on points
    //  15%  Liquidity            — 150M — DEX pairs, locked 2 years
    //  12%  Team & Advisors      — 120M — 2-year linear vest, 6-month cliff
    //  12%  Treasury (DAO)       — 120M — governance-controlled
    //  12%  Staking Rewards      — 120M — distributed over 4 years to stakers
    //  10%  Prize Pool (OAI)     — 100M — weekly OAI prizes post-TGE
    //   5%  Referral Rewards     —  50M — OAI bonuses for top referrers
    //   5%  Marketing            —  50M — partnerships, 1-year vest
    //   4%  Ecosystem Fund       —  40M — grants, hackathons

    uint256 public constant LIQUIDITY_ALLOC     = 150_000_000 ether;
    uint256 public constant TEAM_ALLOC          = 120_000_000 ether;
    uint256 public constant TREASURY_ALLOC      = 120_000_000 ether;
    uint256 public constant STAKING_ALLOC       = 120_000_000 ether;
    uint256 public constant PRIZE_ALLOC         = 100_000_000 ether;
    uint256 public constant REFERRAL_ALLOC      =  50_000_000 ether;
    uint256 public constant MARKETING_ALLOC     =  50_000_000 ether;
    uint256 public constant ECOSYSTEM_ALLOC     =  40_000_000 ether;
    // Community airdrop (250M) stays unminted, distributed via mintAirdrop

    uint256 public constant INITIAL_MINT = LIQUIDITY_ALLOC + TEAM_ALLOC + TREASURY_ALLOC
        + STAKING_ALLOC + PRIZE_ALLOC + REFERRAL_ALLOC + MARKETING_ALLOC + ECOSYSTEM_ALLOC; // 750M

    uint256 public totalBurned;

    event TokensBurned(address indexed burner, uint256 amount);

    constructor() ERC20("OracleAI", "OAI") ERC20Permit("OracleAI") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, INITIAL_MINT);
    }

    function mintAirdrop(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    function burnTokens(uint256 amount) external {
        _burn(msg.sender, amount);
        // totalBurned tracked in _update() — no manual increment needed
        emit TokensBurned(msg.sender, amount);
    }

    // Required overrides for ERC20Votes compatibility
    // Also tracks totalBurned for ALL burn paths (burnTokens + inherited burn/burnFrom)
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
        // Track burns regardless of burn path (LOW-04 fix)
        if (to == address(0) && from != address(0)) {
            totalBurned += value;
        }
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
