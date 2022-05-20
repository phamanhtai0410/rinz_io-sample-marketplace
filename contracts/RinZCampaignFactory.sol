// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./RinZCampaign.sol";

contract RinZCampaignFactory is AccessControl {

    event CreateCampaign(
        address campaignAddress,
        address marketplaceAddress,
        address campaignPaymentAddress,
        bool isFixedTokenId,
        uint256 startTimeToBuy,
        uint256 endTimeToBuy,
        IERC20 coinToken,
        string symbol,
        address adminAddress
    );
    event RemoveCampaign(address campaignAddress);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // RinZCampaigns Address list
    address[] rinZCampaignsAddress;

    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*
    *   Create instance of RinZCampaign
    *   @param {address} _campaignPaymentAddress - payment address to receive coinToken when nft have sold
    *   @param {bool} _isFixedTokenId - if true token id of nft is set by owner, else auto increment
    *   @param {uint256} _startTimeToBuy - start time to buy nft the first time on KOLs page
    *   @param {uint256} _endTimeToBuy - end time to buy nft the first time on KOLs page
    *   @param {IERC20} _coinToken - currency that KOLs want to sell nft campaign
    *   @param {string} _symbol - symbol of this campaign
    *   @param {address} _adminAddress - admin address have access control to this campaign
    */
    function createCampaign(
        address _marketplaceAddress,
        address _campaignPaymentAddress,
        bool _isFixedTokenId, 
        uint256 _startTimeToBuy,
        uint256 _endTimeToBuy,
        IERC20 _coinToken,
        string memory _symbol
        ) public onlyRole(ADMIN_ROLE) {
        RinZCampaign campaign = new RinZCampaign(
            _marketplaceAddress,
            _campaignPaymentAddress,
            _isFixedTokenId,
            _startTimeToBuy,
            _endTimeToBuy,
            _coinToken,
            _symbol,
            msg.sender
        );

        address campaignAddress = address(campaign);
        rinZCampaignsAddress.push(campaignAddress);
        
        emit CreateCampaign(
            campaignAddress,
            _marketplaceAddress,
            _campaignPaymentAddress,
            _isFixedTokenId,
            _startTimeToBuy,
            _endTimeToBuy,
            _coinToken,
            _symbol,
            msg.sender
        );
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getAllCampaign() public view onlyRole(ADMIN_ROLE) returns(address[] memory) {
        return rinZCampaignsAddress;
    }

    function removeCampaign(address campaignAddress) public onlyRole(ADMIN_ROLE) {
        for (uint256 i; i < rinZCampaignsAddress.length; i++) {
            if (rinZCampaignsAddress[i] == campaignAddress) {
                rinZCampaignsAddress[i] = rinZCampaignsAddress[rinZCampaignsAddress.length - 1];
                rinZCampaignsAddress.pop();
            }
        }
        emit RemoveCampaign(campaignAddress);
    }
}