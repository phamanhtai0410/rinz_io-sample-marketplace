// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RinZCampaign.sol";
import "./RinZNFTMarketItem.sol";
import "./IRinZCampaign.sol";
import "./RinZNFTMarketCampaign.sol";

contract RinZNFTMarket is ERC1155Holder, Ownable {

    using RinZNFTMarketItem for RinZNFTMarketItem.MarketItem;
    using RinZNFTMarketCampaign for RinZNFTMarketCampaign.MarketCampaign;
    using Counters for Counters.Counter;

    event CampaignRegistered(address campaign, uint256 discountFee, address paymentAddress);
    event Sale(
        uint256 marketId,
        address owner,
        address campaign,
        uint256 tokenId,
        uint256 pricePerItem,
        string metadataUri,
        uint256 amount
    );
    event Buy(uint256 marketId, address buyer, uint256 amount);
    event FirstBuy(
        address campaign, 
        uint256 tokenId, 
        uint256 amount, 
        address owner
    );

    uint public constant TOKEN_DECIMAL = 10 ** 18;

    IERC20 public coinToken;
    IRinZCampaign public rinZCampaign;

    Counters.Counter public marketIdCounter;

    mapping (address => RinZNFTMarketCampaign.MarketCampaign) public campaignSellOnMarket;
    RinZNFTMarketItem.MarketItem[] public itemSellOnMarket;


    function setCoinToken(
        IERC20 coinToken_
    ) external {
        coinToken = coinToken_;
    }

    function setRinZCampaign(IRinZCampaign rinZCampaign_) internal {
        rinZCampaign = rinZCampaign_;
    }

    /*New campaign should call this function to sale item on market*/
    //       @param {address} campaign ---- deployed address of campaign
    //       @param {uint256} discount ---- discount fee will receive after sale item
    //       @param {address} paymentAddress ---- an address to receive payment from discount fee

    function campaignRegister(address campaign, uint256 discountFee, address paymentAddress) external onlyOwner {
        require(_isCampaignRegistered(campaign) != true, "Campaign have registered");

        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign_;
        marketCampaign_.isActiveSale = true;
        marketCampaign_.discountFee = discountFee;
        marketCampaign_.paymentAddress = paymentAddress;

        campaignSellOnMarket[campaign] = marketCampaign_;

        // emit event registered
        emit CampaignRegistered(campaign, discountFee, paymentAddress);
    }

    /** Marketplace fee */
    function marketFee(uint256 amount) internal pure returns (uint256 fee) {
        // TODO check rate
        fee = (amount / 1000) * 45;
    }

    /** Discount fee for kol */
    function discountFeeForCampaignOwner(uint256 amount, uint256 percent) internal pure returns (uint256 fee) {
        // TODO check rate
        fee = amount * percent / 1000;
    }

    /** Sale token */
    function sale(IRinZCampaign campaign, uint256 tokenId, uint256 pricePerItem, uint256 amount) external {

        // Set rinz campaign caller
        setRinZCampaign(campaign);

        require(rinZCampaign.getBalanceOf(msg.sender, tokenId) > 0, "NFT not owned");
        
        // Seller Address
        address owner = msg.sender;

        // Address of marketplace
        address marketOwnerAddress = address(this);

        // Market hole token for sale
        rinZCampaign.sendNft(owner, marketOwnerAddress, tokenId, amount, "0x00");

        uint256 marketId = marketIdCounter.current();
        marketIdCounter.increment();
        RinZNFTMarketItem.MarketItem memory marketItem;
        string memory metadataUri = rinZCampaign.getUri(tokenId);

        marketItem.marketId = marketId;
        marketItem.tokenId = tokenId;
        marketItem.campaign = address(campaign);
        marketItem.amount = amount;
        marketItem.pricePerItem = pricePerItem * TOKEN_DECIMAL;
        marketItem.metadataUri = metadataUri;
        marketItem.owner = owner;

        itemSellOnMarket.push(marketItem);

        emit Sale(marketId, owner, address(campaign), tokenId, pricePerItem, metadataUri, amount);
    }

    // Fist buy from the campaign,
    // should check quantity in db before call this function to avoid out of token supply
    function firstBuy(IRinZCampaign campaign, uint256 tokenId, uint256 pricePerItem, uint256 amount) external {
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

    /** Buy token */
    function buy(uint256 marketId, uint256 amount) external {
        // Buyer Address
        address buyer = msg.sender;
        // Address of marketplace
        address marketOwnerAddress = address(this);
        RinZNFTMarketItem.MarketItem memory marketItem;
        for (uint256 i; i < itemSellOnMarket.length; ++i) {
            RinZNFTMarketItem.MarketItem memory marketItem_ = itemSellOnMarket[i];
            if (marketItem_.marketId == marketId) {
                marketItem = marketItem_;
            }
        }

        require(_isCampaignActive(marketItem.campaign) == true, "Campaign have deactivated");
        require(marketItem.amount >= amount, "Not enough amount");
        require(marketItem.owner != buyer, "You can't buy your own item");

        uint256 totalPrice = marketItem.pricePerItem * amount;
        // Total marketFee
        uint256 marketPlaceFee = marketFee(totalPrice);
        
        // get campaign registered info
        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign = campaignSellOnMarket[marketItem.campaign];

        if (marketCampaign.discountFee > 0) {
            // Discount fee for kol
            uint256 discountFee = discountFeeForCampaignOwner(totalPrice, marketCampaign.discountFee);
            // Fee for kol
            coinToken.transferFrom(buyer, marketCampaign.paymentAddress, discountFee);
        }
        // Fee for market
        coinToken.transferFrom(buyer, marketOwnerAddress, marketPlaceFee);

        // Profit for the owner (total price - marketPlaceFee - discountFee)
        coinToken.transferFrom(buyer, marketItem.owner, totalPrice - marketPlaceFee - discountFee);

        // Set rinz campaign caller
        setRinZCampaign(IRinZCampaign(marketItem.campaign));
        // Market sendNft to buyer
        rinZCampaign.sendNft(marketOwnerAddress, buyer, marketItem.tokenId, amount, "0x00");

        // update marketItem amount

        emit Buy(marketId, buyer, amount);
    }

    function _isCampaignRegistered(address campaign) public view returns (bool) {
        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign_ = campaignSellOnMarket[campaign];
        return marketCampaign_.paymentAddress != address(0);
    }

    function changeCampaignInfo(
        address campaign,
         bool isActive, 
         uint256 discountFee,
          address paymentAddress
        ) external onlyOwner {
        require(_isCampaignRegistered(campaign) == true, "Campaign haven't registered");
        campaignSellOnMarket[campaign].isActiveSale = isActive;
        campaignSellOnMarket[campaign].discountFee = discountFee;
        campaignSellOnMarket[campaign].paymentAddress = paymentAddress;
    }

    function _isCampaignActive(address campaign) public view returns (bool) {
        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign_ = campaignSellOnMarket[campaign];
        return marketCampaign_.isActiveSale;
    }

    function getAllMarketItems() external view returns (RinZNFTMarketItem.MarketItem[] memory) {
        return itemSellOnMarket;
    }
}
