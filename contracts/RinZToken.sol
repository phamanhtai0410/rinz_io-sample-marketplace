// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RinZToken is ERC20 {
    constructor() ERC20("RinZToken", "RZT") {
        _mint(msg.sender, 1000 * 10 ** 6 * (10 ** 18));
    }
}
