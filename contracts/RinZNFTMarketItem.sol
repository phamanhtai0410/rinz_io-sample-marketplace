// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library RinZNFTMarketItem {
    struct MarketItem {
        uint256 marketId;           // index of market item
        uint256 tokenId;            // tokenId 
        address campaign;           // nft address (campaign address)
        uint256 amount;             // sell amount
        uint256 pricePerItem;       // price of each token
        string metadataUri;                 // uri (.json) token metadata
        address owner;              // owner of marketItem (seller)
    }
}