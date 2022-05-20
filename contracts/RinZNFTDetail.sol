// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

library RinZNFTDetail {
    struct NFTDetail {
        uint16 tokenId;         // tokenId mint to nftAddress
        uint8 tokenType;        // type of nft
        uint256 quantity;       // amount of TokenId
        string uri;             // uri (.json) of tokenId metadata
        bool isOpened;          // true if box opened. if its not a box, it's always true
        address owner;          // owner of tokenId
    }
}
