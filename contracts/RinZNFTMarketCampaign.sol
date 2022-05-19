// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library RinZNFTMarketCampaign {
    struct MarketCampaign {
        bool isActiveSale;       // Active sale on market
        uint16 discountPercent;    // discount percent will receive after sale item on market
        address paymentAddress; // payment address receive discount fee
    }
}