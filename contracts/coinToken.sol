// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract coinToken is ERC20 {
    constructor() ERC20("coinToken", "cT") {
        _mint(msg.sender, 1000 * 10 ** 6 * (10 ** 18));
    }
}