// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

interface IPointsQuest {
    function addPoints(address user, uint256 amount, uint256 streak) external;
}

/**
 * @title QuestClaim
 * @notice On-chain quest reward claims with backend signature verification.
 *         Backend signs a message approving the claim, user submits tx.
 *         Contract verifies signature and calls Points.addPoints().
 */
contract QuestClaim is AccessControl {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    IPointsQuest public immutable pointsContract;
    address public signer; // backend wallet that signs claim approvals

    // claimed[keccak256(user, questId)] = true — prevents double claims
    mapping(bytes32 => bool) public claimed;

    event QuestClaimed(address indexed user, string questId, uint256 points);
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);

    constructor(address _points, address _signer) {
        require(_points != address(0), "Invalid points address");
        require(_signer != address(0), "Invalid signer address");
        pointsContract = IPointsQuest(_points);
        signer = _signer;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Claim quest reward. User signs the tx, backend signs the approval.
     * @param questId Unique quest identifier (e.g., "daily-checkin")
     * @param points Number of points to award
     * @param nonce Unique nonce to prevent replay attacks
     * @param deadline Timestamp after which the signature expires
     * @param signature Backend signature approving this claim
     */
    function claim(
        string calldata questId,
        uint256 points,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "Signature expired");
        bytes32 claimKey = keccak256(abi.encodePacked(msg.sender, questId, nonce));
        require(!claimed[claimKey], "Already claimed");
        require(points > 0, "Zero points");

        // Reconstruct the message that backend signed (includes deadline + chainId)
        bytes32 messageHash = keccak256(
            abi.encodePacked(msg.sender, questId, points, nonce, deadline, block.chainid, address(this))
        );
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();

        // Verify backend signature
        address recovered = ethSignedHash.recover(signature);
        require(recovered == signer, "Invalid signature");

        // Mark as claimed and award points
        claimed[claimKey] = true;
        pointsContract.addPoints(msg.sender, points, 0);

        emit QuestClaimed(msg.sender, questId, points);
    }

    // Legacy claim removed — all claims now require deadline for security (M-02)

    /**
     * @notice Check if a specific quest+nonce has been claimed by a user
     */
    function isClaimed(address user, string calldata questId, uint256 nonce) external view returns (bool) {
        return claimed[keccak256(abi.encodePacked(user, questId, nonce))];
    }

    /**
     * @notice Update the backend signer address (admin only)
     */
    function setSigner(address _newSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newSigner != address(0), "Invalid signer");
        emit SignerUpdated(signer, _newSigner);
        signer = _newSigner;
    }
}
