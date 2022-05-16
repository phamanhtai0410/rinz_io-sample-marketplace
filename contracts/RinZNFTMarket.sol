// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./RinZCampaign.sol";
import "./RinZNFTMarketItem.sol";
import "./IRinZCampaign.sol";
import "./RinZNFTMarketCampaign.sol";

contract RinZNFTMarket is ERC1155Holder {

    using RinZNFTMarketItem for RinZNFTMarketItem.MarketItem;
    using RinZNFTMarketCampaign for RinZNFTMarketCampaign.MarketCampaign;
    using Counters for Counters.Counter;

    uint public constant TOKEN_DECIMAL = 10 ** 18;

    IERC20 public coinToken;
    IRinZCampaign public rinZCampaign;

    Counters.Counter public marketIdCounter;

    RinZNFTMarketCampaign.MarketCampaign[] public campaignSellOnMarket;
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

    function campaignRegister(address campaign, uint256 discount, address paymentAddress) external {
        require(_isCampaignRegistered(campaign) != true, "Campaign have registered");

        RinZNFTMarketCampaign.MarketCampaign memory marketCampaign_;
        marketCampaign_.campaign = campaign;
        marketCampaign_.discountFee = discount;
        marketCampaign_.paymentAddress = paymentAddress;

        campaignSellOnMarket.push(marketCampaign_);

        // emit event registered
    }

    /** Marketplace fee */
    function marketFee(uint256 amount) internal pure returns (uint256 fee) {
        // TODO check rate
        fee = (amount / 1000) * 45;
    }

    /** Sale token */
    function sale(IRinZCampaign campaign, uint256 tokenId, uint256 pricePerItem, uint256 amount) external {

        // Set rinz campaign caller
        setRinZCampaign(campaign);
        // Seller Address
        address owner = msg.sender;

        // Address of marketplace
        address marketOwnerAddress = address(this);

        // Market hole token for sale
        rinZCampaign.sendNft(owner, marketOwnerAddress, tokenId, amount, "0x00");

        uint256 marketId = marketIdCounter.current();
        marketIdCounter.increment();
        RinZNFTMarketItem.MarketItem memory marketItem;

        marketItem.marketId = marketId;
        marketItem.tokenId = tokenId;
        marketItem.campaign = address(campaign);
        marketItem.amount = amount;
        marketItem.pricePerItem = pricePerItem * TOKEN_DECIMAL;
        marketItem.metadataUri = rinZCampaign.getUri(tokenId);
        marketItem.owner = owner;

        campaignSellOnMarket.push(address(campaign));
        //        emit Sale(to, tokenId, amount, pricePerItem);
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

        // TODO: check marketItem.amount >= amount

        uint256 totalPrice = marketItem.pricePerItem * amount;
        // Total fee
        uint256 fee = marketFee(totalPrice);

        // Fee for market
        coinToken.transferFrom(buyer, marketOwnerAddress, fee);

        // Profit for the owner (total price - fee)
        coinToken.transferFrom(buyer, marketItem.owner, totalPrice - fee);

        // Set rinz campaign caller
        setRinZCampaign(IRinZCampaign(marketItem.campaign));
        // Market sendNft to buyer
        rinZCampaign.sendNft(marketOwnerAddress, buyer, marketItem.tokenId, amount, "0x00");

        // update marketItem amount

        //        emit Buy(to, tokenId, boxDetail.price, boxDetail.owner_by);
    }

    function _isCampaignRegistered(address campaign) internal returns (bool) {
        for (uint256 i; i < campaignSellOnMarket.length; ++i) {
            RinZNFTMarketCampaign.MarketCampaign memory marketCampain_ = campaignSellOnMarket[i];
            if (marketCampain_.campaign == campaign) return true;
        }
        return false;
    }

}
