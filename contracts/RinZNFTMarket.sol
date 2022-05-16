// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./RinZCampaign.sol";
import "./RinZNFTMarketItem.sol";

contract RinZNFTMarket is ERC1155Holder {

    using RinZNFTMarketItem for RinZNFTMarketItem.MarketItem;
    using Counters for Counters.Counter;

    uint public constant TOKEN_DECIMAL = 10 ** 18;

    IERC20 public coinToken;
    RinZCampaign public rinZCampaign;

    Counters.Counter public marketIdCounter;

    address[] public campaignSellOnMarket;
    RinZNFTMarketItem.MarketItem[] public itemSellOnMarket;
    mapping (address => RinZNFTMarketItem.MarketItem[]) marketItemByCampaign;
    mapping (uint256 => RinZNFTMarketItem.MarketItem[]) marketItemByTokenId;
    mapping (address => RinZNFTMarketItem.MarketItem[]) marketItemByOwner;

    function setCoinToken(
        IERC20 coinToken_,
        RinZCampaign rinZCampaign_
    ) external {
        coinToken = coinToken_;
        rinZCampaign = rinZCampaign_;
    }

    /** Marketplace fee */
    function marketFee(uint256 amount) internal pure returns (uint256 fee) {
        // TODO check rate
        fee = (amount / 1000) * 45;
    }

    /** Sale token */
    function sale(address campaign, uint256 tokenId, uint256 pricePerItem, uint256 amount) external {
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
        marketItem.campaign = campaign;
        marketItem.amount = amount;
        marketItem.pricePerItem = pricePerItem * TOKEN_DECIMAL;                
        marketItem.metadataUri = rinZCampaign.uri(tokenId);
        marketItem.owner = owner;    

        campaignSellOnMarket.push(campaign);
        itemSellOnMarket.push(marketItem);

        RinZNFTMarketItem.MarketItem[] storage itemsByCampaign = marketItemByCampaign[campaign];
        itemsByCampaign.push(marketItem);

        RinZNFTMarketItem.MarketItem[] storage itemsByTokenId = marketItemByTokenId[tokenId];
        itemsByTokenId.push(marketItem);

        RinZNFTMarketItem.MarketItem[] storage itemsByOwner = marketItemByOwner[owner];
        itemsByOwner.push(marketItem);
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

        // Market sendNft to buyer
        rinZCampaign.sendNft(marketOwnerAddress, buyer, marketItem.tokenId, amount, "0x00");

        // update marketItem amount

        if (marketItem.amount > amount) {
            updateMarketItemAfterBuy(marketItem, amount);
        }
        removeMarketItemAfterBuy(marketItem);

//        emit Buy(to, tokenId, boxDetail.price, boxDetail.owner_by);
    }


    function getMarketItemsByTokenId(uint256 tokenId) external view returns (RinZNFTMarketItem.MarketItem[] memory) {
        RinZNFTMarketItem.MarketItem[] memory result = marketItemByTokenId[tokenId];
        return result;
    }

    function getMarketItemsByCampaign(address campaign) external view returns (RinZNFTMarketItem.MarketItem[] memory) {
        RinZNFTMarketItem.MarketItem[] memory result = marketItemByCampaign[campaign];
        return result;
    }

    function getMarketItemsByOwner(address owner) external view returns (RinZNFTMarketItem.MarketItem[] memory) {
        RinZNFTMarketItem.MarketItem[] memory result = marketItemByOwner[owner];
        return result;
    }

    function updateMarketItemAfterBuy(RinZNFTMarketItem.MarketItem memory marketItem, uint256 amount) internal {

        RinZNFTMarketItem.MarketItem[] storage itemsByCampaign = marketItemByCampaign[marketItem.campaign];
        for (uint256 i; i < itemsByCampaign.length; ++i) {
            if (itemsByCampaign[i].marketId != marketItem.marketId) continue;
            
            RinZNFTMarketItem.MarketItem memory marketItem_ = itemsByCampaign[i];
            marketItem_.amount = marketItem_.amount - amount;

            itemsByCampaign[i] = marketItem_;
        }

        RinZNFTMarketItem.MarketItem[] storage itemsByTokenId = marketItemByTokenId[marketItem.tokenId];
        for (uint256 i; i < itemsByTokenId.length; ++i) {
            if (itemsByTokenId[i].marketId != marketItem.marketId) continue;
            
            RinZNFTMarketItem.MarketItem memory marketItem_ = itemsByTokenId[i];
            marketItem_.amount = marketItem_.amount - amount;

            itemsByTokenId[i] = marketItem_;
        }

        RinZNFTMarketItem.MarketItem[] storage itemsByOwner = marketItemByOwner[marketItem.owner];
        for (uint256 i; i < itemsByOwner.length; ++i) {
            if (itemsByOwner[i].marketId != marketItem.marketId) continue;
            
            RinZNFTMarketItem.MarketItem memory marketItem_ = itemsByOwner[i];
            marketItem_.amount = marketItem_.amount - amount;

            itemsByOwner[i] = marketItem_;
        }

        for (uint256 i; i < itemSellOnMarket.length; ++i) {
            if (itemSellOnMarket[i].marketId != marketItem.marketId) continue;

            RinZNFTMarketItem.MarketItem memory marketItem_ = itemSellOnMarket[i];
            marketItem_.amount = marketItem_.amount - amount;

            itemSellOnMarket[i] = marketItem_;
        }
    }

    function removeMarketItemAfterBuy(RinZNFTMarketItem.MarketItem memory marketItem) internal {

        RinZNFTMarketItem.MarketItem[] storage itemsByCampaign = marketItemByCampaign[marketItem.campaign];
        for (uint256 i; i < itemsByCampaign.length; ++i) {
            if (itemsByCampaign[i].marketId == marketItem.marketId) {
                delete itemsByCampaign[i];
            }
        }

        RinZNFTMarketItem.MarketItem[] storage itemsByTokenId = marketItemByTokenId[marketItem.tokenId];
        for (uint256 i; i < itemsByTokenId.length; ++i) {
            if (itemsByTokenId[i].marketId == marketItem.marketId) {
                delete itemsByTokenId[i];
            }
        }

        RinZNFTMarketItem.MarketItem[] storage itemsByOwner = marketItemByOwner[marketItem.owner];
        for (uint256 i; i < itemsByOwner.length; ++i) {
            if (itemsByOwner[i].marketId != marketItem.marketId) {
                delete itemsByOwner[i];
            }
        }

        for (uint256 i; i < itemSellOnMarket.length; ++i) {
            if (itemSellOnMarket[i].marketId == marketItem.marketId) {
                delete itemSellOnMarket[i];
            }
        }
    }

}
