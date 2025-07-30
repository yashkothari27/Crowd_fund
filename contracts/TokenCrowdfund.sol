// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Crowdfunding is ReentrancyGuard {
    IERC20 public immutable token;

    struct Campaign {
        address owner;
        uint256 goal;
        uint256 pledged;
        uint256 deadline;
        bool claimed;
    }

    uint256 public campaignIdCount;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public pledges;

    event CampaignCreated(uint256 indexed campaignId, address indexed owner, uint256 goal, uint256 deadline);
    event Pledged(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event Withdrawn(uint256 indexed campaignId, address indexed owner, uint256 amount);
    event Refunded(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "Token address required");
        token = IERC20(_token);
    }

    modifier onlyOwner(uint256 _campaignId) {
        require(campaigns[_campaignId].owner == msg.sender, "Not campaign owner");
        _;
    }

    function createCampaign(uint256 _goal, uint256 _duration) external returns (uint256) {
        require(_goal > 0, "Goal required");
        require(_duration > 0, "Duration required");

        campaignIdCount += 1;
        uint256 cid = campaignIdCount;

        campaigns[cid] = Campaign({
            owner: msg.sender,
            goal: _goal,
            pledged: 0,
            deadline: block.timestamp + _duration,
            claimed: false
        });

        emit CampaignCreated(cid, msg.sender, _goal, block.timestamp + _duration);
        return cid;
    }

    function pledge(uint256 _campaignId, uint256 _amount) external nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(_amount > 0, "Amount required");

        token.transferFrom(msg.sender, address(this), _amount);
        campaign.pledged += _amount;
        pledges[_campaignId][msg.sender] += _amount;

        emit Pledged(_campaignId, msg.sender, _amount);
    }

    function claimFunds(uint256 _campaignId) external nonReentrant onlyOwner(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign not ended");
        require(!campaign.claimed, "Already claimed");
        require(campaign.pledged >= campaign.goal, "Goal not reached");

        campaign.claimed = true;
        uint256 amount = campaign.pledged;
        campaign.pledged = 0;
        token.transfer(msg.sender, amount);

        emit Withdrawn(_campaignId, msg.sender, amount);
    }

    function refund(uint256 _campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign not ended");
        require(campaign.pledged < campaign.goal, "Goal was met");

        uint256 pledgedAmount = pledges[_campaignId][msg.sender];
        require(pledgedAmount > 0, "No pledge to refund");

        pledges[_campaignId][msg.sender] = 0;
        token.transfer(msg.sender, pledgedAmount);

        emit Refunded(_campaignId, msg.sender, pledgedAmount);
    }
}
