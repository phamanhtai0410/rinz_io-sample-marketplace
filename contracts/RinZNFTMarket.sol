// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RinZCampaign.sol";
import "./RinZNFTMarketItem.sol";
import "./RinZNFTMarketCampaign.sol";

contract RinZNFTMarket is ERC1155Holder, Ownable {

    using RinZNFTMarketItem for RinZNFTMarketItem.MarketItem;
    using RinZNFTMarketCampaign for RinZNFTMarketCampaign.MarketCampaign;
    using Counters for Counters.Counter;

    event CampaignRegistered(address campaign, uint16 discountPercent, address paymentAddress);
    event Sale(
        uint256 marketId,
        address owner,
        address campaign,
        uint256 tokenId,
        uint256 pricePerItem,
        string metadataUri,
        uint256 amount
    );
    event Buy(uint256 marketId, address buyer, uint256 pricePerItem, uint256 amount, uint256 commissionFee, uint256 marketPlaceFee);
    event DeactiveSale(uint256 marketId);

    uint public constant TOKEN_DECIMAL = 10 ** 18;

    IERC20 public coinToken;

    Counters.Counter public marketIdCounter;

    uint256 public totalMarketItem = 0;

    mapping (address => RinZNFTMarketCampaign.MarketCampaign) public campaignSellOnMarket;
    mapping (uint256 => RinZNFTMarketItem.MarketItem) public itemSellOnMarket;


    function setCoinToken(
        IERC20 _coinToken
    ) public onlyOwner {
        coinToken = _coinToken;
    }

    /*New campaign should call this function to sale item on market*/
    //       @param {address} campaign ---- deployed address of campaign
    //       @param {uint256} discountPercent ---- discount percent will receive after sale item
    //       @param {address} paymentAddress ---- an address to receive payment from discount fee

    function campaignRegister(address _campaign, uint16 _discountPercent, address _paymentAddress) public onlyOwner {
        require(!_isCampaignRegistered(_campaign), "Campaign have registered");

        RinZNFTMarketCampaign.MarketCampaign memory _marketCampaign;
        _marketCampaign.isActiveSale = true;
        _marketCampaign.discountPercent = _discountPercent;
        _marketCampaign.paymentAddress = _paymentAddress;

        campaignSellOnMarket[_campaign] = _marketCampaign;

        // emit event registered
        emit CampaignRegistered(_campaign, _discountPercent, _paymentAddress);
    }

    /** Marketplace fee */
    function _marketFee(uint256 _amount) internal pure returns (uint256 fee) {
        // TODO check rate
        fee = (_amount / 1000) * 45;
    }

    /** Discount fee for kol */
    function _discountFeeForCampaignOwner(uint256 _amount, uint16 _percent) internal pure returns (uint256 fee) {
        // TODO check rate
        fee = _amount * _percent / 1000;
    }

    /** Sale token */
    function sale(address _campaign, uint256 _tokenId, uint256 _pricePerItem, uint256 _amount) external {
        require(ERC1155(_campaign).balanceOf(msg.sender, _tokenId) > 0, "NFT not owned");
        require(ERC1155(_campaign).balanceOf(msg.sender, _tokenId) >= _amount, "Out of supply owned");
        require(_isCampaignActive(_campaign), "Campaign have deactivated");
        
        // Seller Address
        address owner = msg.sender;

        // Address of marketplace
        address marketOwnerAddress = address(this);

        // Approve for market
        ERC1155(_campaign).setApprovalForAll(marketOwnerAddress, true);

        // Market hole token for sale
        ERC1155(_campaign).safeTransferFrom(owner, marketOwnerAddress, _tokenId, _amount, "0x00");

        uint256 marketId = marketIdCounter.current();
        marketIdCounter.increment();
        RinZNFTMarketItem.MarketItem memory marketItem;
        string memory metadataUri = ERC1155(_campaign).uri(_tokenId);

        marketItem.marketId = marketId;
        marketItem.tokenId = _tokenId;
        marketItem.campaign = _campaign;
        marketItem.amount = _amount;
        marketItem.pricePerItem = _pricePerItem * TOKEN_DECIMAL;
        marketItem.metadataUri = metadataUri;
        marketItem.owner = owner;
        marketItem.isOnSale = true;

        itemSellOnMarket[marketId] = marketItem;
        totalMarketItem += 1;

        emit Sale(marketId, owner, _campaign, _tokenId, _pricePerItem, metadataUri, _amount);
    }

    function deactiveSale(uint256 marketId) external {
        RinZNFTMarketItem.MarketItem storage marketItem = itemSellOnMarket[marketId];
        require(marketItem.owner == msg.sender, "Token not owned");
        require(marketItem.isOnSale, "Token already off chain");
        
        marketItem.isOnSale = false;
        // Decrease total marketItem
        totalMarketItem -= 1;
        address marketOwnerAddress = address(this);
        // Approve for owner
        //ERC1155(marketItem.campaign).setApprovalForAll(marketItem.owner, true);
        // Transfer token to owner
        ERC1155(marketItem.campaign).safeTransferFrom(
            marketOwnerAddress,
            marketItem.owner, 
            marketItem.tokenId, 
            marketItem.amount, 
            "0x00"
        );

        emit DeactiveSale(marketId);
    }

    // Fist buy from the campaign,
    // should check quantity in db before call this function to avoid out of token supply
 /*   function firstBuy(IRinZCampaign campaign, uint256 tokenId, uint256 pricePerItem, uint256 amount) external {
        require(_isCampaignRegistered(address(campaign)) == true, "Campaign haven't registered");
        require(_isCampaignActive(address(campaign)) == true, "Campaign have deactivated");

        // Set rinz campaign caller
        setRinZCampaign(campaign);

        // buyer address
        address buyer = msg.sender;
        // Address of marketplace
        address marketOwnerAddress = address(this);

        rinZCampaign.mint(buyer, tokenId, amount, "0x00");

        uint256 totalPrice = pricePerItem * amount;
        // Total fee
        uint256 marketPlaceFee = marketFee(totalPrice);

        // Fee for market
        coinToken.transferFrom(buyer, marketOwnerAddress, marketPlaceFee);

        // get campaign registered info
        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign = campaignSellOnMarket[address(campaign)];

        // Profit for the owner (total price - fee)
        coinToken.transferFrom(buyer, marketCampaign.paymentAddress, totalPrice - marketPlaceFee);

        // uint256 marketId = marketIdCounter.current();
        // marketIdCounter.increment();
        // string memory metadataUri = rinZCampaign.getUri(tokenId);

        emit FirstBuy(address(campaign), tokenId, amount, buyer);
    }
*/

    /** Buy token */
    // amount now is set to 1, in the future will be set with amount user want to
    function buy(uint256 _marketId, uint256 _pricePerItem, uint256 _amount) external {
        // Buyer Address
        address buyer = msg.sender;
        // Address of marketplace
        address marketOwnerAddress = address(this);
        RinZNFTMarketItem.MarketItem memory marketItem = itemSellOnMarket[_marketId];

        require(_isCampaignActive(marketItem.campaign), "Campaign have deactivated");
        require(marketItem.amount >= _amount, "Not enough amount");
        require(marketItem.owner != buyer, "You can't buy your own item");

        uint256 totalPrice = _pricePerItem * _amount;
        // Total marketFee
        uint256 marketPlaceFee = _marketFee(totalPrice);
        
        // get campaign registered info
        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign = campaignSellOnMarket[marketItem.campaign];

        // TODO: Decrease coinToken transfer from 3 to 2
        // market will hold fee and send to kol when they send withdraw request
        uint256 commissionFee = 0;
         // Fee for market
        coinToken.transferFrom(buyer, marketOwnerAddress, marketPlaceFee);

        if (marketCampaign.discountPercent > 0) {
            // Discount fee for kol
            commissionFee = _discountFeeForCampaignOwner(totalPrice, marketCampaign.discountPercent);
            // Fee for kol
            coinToken.transferFrom(buyer, marketCampaign.paymentAddress, commissionFee);
        }
       
        // Profit for the kol (total price - marketPlaceFee - commissionFee)
        uint256 kolProfit = totalPrice - marketPlaceFee - commissionFee;
        coinToken.transferFrom(buyer, marketItem.owner, kolProfit);
        
        // Market send nft to buyer
        ERC1155(marketItem.campaign).setApprovalForAll(marketOwnerAddress, true);
        ERC1155(marketItem.campaign).safeTransferFrom(marketOwnerAddress, buyer, marketItem.tokenId, _amount, "0x00");

        // update marketItem amount
        totalMarketItem -= 1;

        emit Buy(_marketId, buyer, _pricePerItem, _amount, commissionFee, marketPlaceFee);
    }

    function _isCampaignRegistered(address campaign) internal view returns (bool) {
        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign_ = campaignSellOnMarket[campaign];
        return marketCampaign_.paymentAddress != address(0);
    }

    function changeCampaignInfo(
        address _campaign,
        bool _isActive, 
        uint16 _discountPercent,
        address _paymentAddress
        ) public onlyOwner {
        require(_isCampaignRegistered(_campaign), "Campaign haven't registered");
        campaignSellOnMarket[_campaign].isActiveSale = _isActive;
        campaignSellOnMarket[_campaign].discountPercent = _discountPercent;
        campaignSellOnMarket[_campaign].paymentAddress = _paymentAddress;
    }

    function _isCampaignActive(address _campaign) public view returns (bool) {
        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign_ = campaignSellOnMarket[_campaign];
        return marketCampaign_.isActiveSale;
    }
}
