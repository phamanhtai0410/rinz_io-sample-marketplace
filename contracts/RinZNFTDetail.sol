// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library RinZNFTDetail {
    struct NFTDetail {
        address nftAddress;      // address to identify campaign
        uint256 tokenId;        // tokenId mint to nftAddress
        uint256 amount;         // amountOfTokenId
        string uri;             // uri (.json) of tokenId metadata
    }
}