// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IRinZCampaign {

    function getUri(uint256 tokenId) external returns (string memory);

    function getBalanceOf(address account, uint256 tokenId) external returns (uint256);

    function sendNft(address from, address to, uint256 tokenId, uint256 amount, bytes calldata data) external;

    function mint(address owner, uint256 tokenId, uint256 amount, bytes calldata data) external;
}
