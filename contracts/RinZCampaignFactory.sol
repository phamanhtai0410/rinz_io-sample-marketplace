// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RinZCampaign.sol";

contract RinZCampaignFactory is Ownable {

    event CreateCampaign(
        address campaignAddress,
        address marketplaceAddress,
        address campaignPaymentAddress,
        string baseMetadataURI,
        bool isFixedTokenId,
        uint256 startTimeToBuy,
        uint256 endTimeToBuy,
        IERC20 coinToken,
        string symbol
    );

    // RinZCampaigns Address list
    address[] RinZCampaignsAddress;

    /*
    *   Create instance of RinZCampaign
    *   @param {address} _campaignPaymentAddress - payment address to receive coinToken when nft have sold
    *   @param {string} _baseMetadataURI - base metadata uri of token
    *   @param {bool} _isFixedTokenId - if true token id of nft is set by owner, else auto increment
    *   @param {uint256} _startTimeToBuy - start time to buy nft the first time on KOLs page
    *   @param {uint256} _endTimeToBuy - end time to buy nft the first time on KOLs page
    *   @param {IERC20} _coinToken - currency that KOLs want to sell nft campaign
    *   @param {string} _symbol - symbol of this campaign
    */
    function createCampaign(
        address _marketplaceAddress,
        address _campaignPaymentAddress,
        string memory _baseMetadataURI, 
        bool _isFixedTokenId, 
        uint256 _startTimeToBuy,
        uint256 _endTimeToBuy,
        IERC20 _coinToken,
        string memory _symbol
        ) public onlyOwner {
        RinZCampaign campaign = new RinZCampaign(
            _marketplaceAddress,
            _campaignPaymentAddress,
            _baseMetadataURI,
            _isFixedTokenId,
            _startTimeToBuy,
            _endTimeToBuy,
            _coinToken,
            _symbol
        );

        address campaignAddress = address(campaign);
        RinZCampaignsAddress.push(campaignAddress);
        
        emit CreateCampaign(
            campaignAddress,
            _marketplaceAddress,
            _campaignPaymentAddress,
            _baseMetadataURI,
            _isFixedTokenId,
            _startTimeToBuy,
            _endTimeToBuy,
            _coinToken,
            _symbol
        );
    }

    function getAllCampaign() public onlyOwner returns(address[] memory) {
        return RinZCampaignsAddress;
    }
}