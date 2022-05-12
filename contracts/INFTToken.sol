// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTToken {
    function openBox(
        address to,
        uint256 count,
        uint256 boxType
    ) external;
}
