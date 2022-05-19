// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library RinZNFTDetail {
    struct NFTDetail {
        uint16 tokenId;         // tokenId mint to nftAddress
        uint8 tokenType;        // type of nft
        uint256 quantity;       // amountOfTokenId
        string uri;             // uri (.json) of tokenId metadata
    }
}
