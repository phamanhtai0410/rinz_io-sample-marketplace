// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library NFTBoxDetails {


    struct BoxDetails {
        uint256 id;
        uint256 index; // index of id in user token array
        uint256 price; // price in BUSD or Token
        uint256 box_type; // 1 -> 3: hero box. 4: gem box
        uint256 on_market; // 0: still private, 1: on market
        uint256 is_opened; // 0: still not open, 1: opened
        address owner_by;  // Owner token before on chain for marketplace.
    }
}
