// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./RinZCampaign.sol";

contract RinZCampaignFactory is AccessControl {

    event CreateCampaign(
        address campaignAddress,
        string baseMetadataUri,
        address campaignPaymentAddress,
        bool isFixedTokenId,
        uint256 whitelistStartTime,
        uint256 publicStartTime,
        uint256 endTimeToBuy,
        IERC20 coinToken,
        string symbol,
        address adminAddress
    );
    event RemoveCampaign(address campaignAddress);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // RinZCampaigns Address list
    address[] public rinZCampaignsAddress;

    // marketplace address
    address public marketAddress;

    constructor(address _marketAddress) {
        marketAddress = _marketAddress;

        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


    /*
    *   Create instance of RinZCampaign
    *   @param {address} _campaignPaymentAddress - payment address to receive coinToken when nft have sold
    *   @param {string} _baseMetadataUri - baseMetadataUri of this campaign
    *   @param {bool} _isFixedTokenId - if true token id of nft is set by owner, else auto increment
    *   @param {uint256} _whitelistStartTime - start time for whitelist to buy nft the first time on KOLs page
    *   @param {uint256} _publicStartTime - start time for all to buy nft the first time on KOLs page
    *   @param {uint256} _endTimeToBuy - end time to buy nft the first time on KOLs page
    *   @param {IERC20} _coinToken - currency that KOLs want to sell nft campaign
    *   @param {string} _symbol - symbol of this campaign
    *   @param {address} _adminAddress - admin address have access control to this campaign
    */
    function createCampaign(
        address _campaignPaymentAddress,
        string memory _baseMetadataUri,
        bool _isFixedTokenId,
        uint256 _whitelistStartTime,
        uint256 _publicStartTime,
        uint256 _endTimeToBuy,
        IERC20 _coinToken,
        string memory _symbol
        ) external onlyRole(ADMIN_ROLE) {
        RinZCampaign campaign = new RinZCampaign(
            marketAddress,
            _baseMetadataUri,
            _campaignPaymentAddress,
            _isFixedTokenId,
            _whitelistStartTime,
            _publicStartTime,
            _endTimeToBuy,
            _coinToken,
            _symbol,
            msg.sender
        );

        rinZCampaignsAddress.push(address(campaign));
        
        emit CreateCampaign(
            address(campaign),
            _baseMetadataUri,
            _campaignPaymentAddress,
            _isFixedTokenId,
            _whitelistStartTime,
            _publicStartTime,
            _endTimeToBuy,
            _coinToken,
            _symbol,
            msg.sender
        );
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getAllCampaign() external view onlyRole(ADMIN_ROLE) returns(address[] memory) {
        return rinZCampaignsAddress;
    }

    function setMarketAddress(address _marketAddress) external onlyRole(ADMIN_ROLE) {
        marketAddress = _marketAddress;
    }
}