// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library RinZNFTDetail {
    struct NFTDetail {
        uint256 tokenId;        // tokenId mint to nftAddress
        uint256 quantity;       // amountOfTokenId
        string uri;             // uri (.json) of tokenId metadata
    }
}
