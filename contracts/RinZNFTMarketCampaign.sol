// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library RinZNFTMarketCampaign {
    struct MarketCampaign {
        bool isActiveSale;       // Active sale on market
        uint256 discountFee;    // discount fee after sale item on market
        address paymentAddress; // payment address receive discount fee
    }
}