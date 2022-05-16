/**
 *  Init used packages
 */

const fs = require("fs");

/**
 * Init compiled contracts artifacts
 */
const RinZToken = artifacts.require("RinZToken");
const RinZCampaign = artifacts.require("RinZCampaign");
const RinZNFTMarket = artifacts.require("RinZNFTMarket");

/**
 * Declares flags for:
 * 1. Re-deploy or Deploy New ?
 */
const DEPLOY_NEW_RINZ_TOKEN = false;
const DEPLOY_NEW_RINZ_CAMPAIGN = false;
const DEPLOY_NEW_RINZ_MARKET = false;

/**
 * Write address of deployed contracts to a file named 'address.txt' in root folder
 * @param {string} name
 * @param {string} address
 */
function wf(name, address) {
    fs.appendFileSync('address.txt', name + "=" + address);
    fs.appendFileSync('address.txt', "\r\n");
}

/**
 * Export migration scenario
 * @param {deployer} deployer
 */
module.exports = async function (deployer) {
    // Log deployer address
    console.log("*** Deployer Address: ", deployer.address);

    // Load address from .env file
    require('dotenv').config();
    // const owner = process.env.OWNER_ADDRESS;

    /**
     * Deploy RinZToken to add to RinZMarket
     */
    let iRinZToken;
    if (DEPLOY_NEW_RINZ_TOKEN) {
        await deployer.deploy(RinZToken);
        iRinZToken = await RinZToken.deployed();
        wf("RinZToken", iRinZToken.address);
    } else {
        iRinZToken = await RinZToken.at(process.env.RINZ_TOKEN_ADDRESS);
    }
    console.log("File: 4_set_up_market.js ~ iRinZToken", iRinZToken);

    /**
     * Deploy RinZCampaign to add to RinZMarket and create new Campaign
     */
    let iRinZCampaign;
    if (DEPLOY_NEW_RINZ_CAMPAIGN) {
        await deployer.deploy(RinZCampaign);
        iRinZCampaign = await RinZCampaign.deployed();
        wf("RinZCampaign", iRinZCampaign.address);
    } else {
        iRinZCampaign = await RinZCampaign.at(process.env.RINZ_CAMPAIGN_ADDRESS);
    }
    console.log("File: 4_set_up_market.js ~ iRinZCampaign", iRinZCampaign);

    /**
     * Deploy RinZNFTMarket
     */
    let iRinZNFTMarket;
    if (DEPLOY_NEW_RINZ_MARKET) {
        await deployer.deploy(RinZNFTMarket);
        iRinZNFTMarket = await RinZNFTMarket.deployed();
        wf("RinZNFTMarket", iRinZNFTMarket.address);
    } else {
        iRinZNFTMarket = await RinZNFTMarket.at(process.env.RINZ_MARKET_ADDRESS);
    }
    console.log("File: 4_set_up_market.js ~ iRinZNFTMarket", iRinZNFTMarket);


    /***
     *      Setup to prepare RinZMarket
     */
    await iRinZNFTMarket.setCoinToken(process.env.RINZ_TOKEN_ADDRESS, process.env.RINZ_CAMPAIGN_ADDRESS);


    /***
     *     Setup RinZCampaign
     *     Quobee campaign have token ids from 1 to 3
     *     Noo Phuoc Thinh have token ids from 4 to 5
     *     @param {address} initialOwner
     *     @param {uint256} initialSupply of tokenId
     *     @param {string} uri - URI of token, can be empty just this version
     *     @param {string} data - Data of token, can be empty just this version
     */

    // Quobee campaign - tokenId = 1, amount 5
    await iRinZCampaign.create(process.env.QUO_BEE_NFT_ADDRESS, 5, '', '0x00');
    // Quobee campaign - tokenId = 2, amount 5
    await iRinZCampaign.create(process.env.QUO_BEE_NFT_ADDRESS, 5, '', '0x00');
    // Quobee campaign - tokenId = 3, amount 5
    await iRinZCampaign.create(process.env.QUO_BEE_NFT_ADDRESS, 5, '', '0x00');

    // Noo campaign - tokenId = 4, amount 6
    await iRinZCampaign.create(process.env.NOO_PHUOC_THINH_NFT_ADDRESS, 6, '', '0x00');
    // Noo campaign - tokenId = 5, amount 6
    await iRinZCampaign.create(process.env.NOO_PHUOC_THINH_NFT_ADDRESS, 6, '', '0x00');



    /***
     *    Logs RinZCampaign of Noo Phuoc Thinh
     *    NOO_PHUOC_THINH_NFT_ADDRESS is the initilizeAddress owner of Noo Phuoc Thinh campaign
     *    @param {address} ownerAddress
     */
    let nooPhuocThinhCampaign = await iRinZCampaign.getNftByOwner(process.env.NOO_PHUOC_THINH_NFT_ADDRESS);
    console.log("File: 4_set_up_market.js ~ nooPhuocThinhCampaign", nooPhuocThinhCampaign);

    /***
     *    Logs RinZCampaign of Quobee
     *    QUO_BEE_NFT_ADDRESS is the initilizeAddress owner of Quobee campaign
     *    @param {address} ownerAddress
     */
    let quobeeCampaign = await iRinZCampaign.getNftByOwner(process.env.QUO_BEE_NFT_ADDRESS);
    console.log("File: 4_set_up_market.js ~ quobeeCampaign", quobeeCampaign);

    /***
     *    Approve to sale Noo Phuoc Thinh campaign on market
     */
    await iRinZCampaign.setApprovalForAll(process.env.RINZ_MARKET_ADDRESS, true);
    console.log("File: 4_set_up_market.js ~ setApprovalForAll Noo Phuoc Thinh campaign", "Done");

    /***
     *    Sale Noo Phuoc Thinh campaign on market
     *    @param {address} campaignAddress
     *    @param {uint256} tokenId
     *    @param {uint256} pricePerItem
     *    @param {uint256} amount
     */
    await iRinZNFTMarket.sale(process.env.NOO_PHUOC_THINH_NFT_ADDRESS, 4, 9, 3);
    console.log("File: 4_set_up_market.js ~ sale Noo Phuoc Thinh campaign on market Done");

    /***
     *   Get market item by owner
     *    @param {address} ownerAddress
     */
    let marketItemOfNoo = await iRinZNFTMarket.getMarketItemsByOwner(process.env.NOO_PHUOC_THINH_NFT_ADDRESS);
    console.log("File: 4_set_up_market.js ~ marketItemOfNoo", marketItemOfNoo);



    /***
     *   Approve to use RinZ token on market
     */
    await iRinZToken.approve(process.env.OWNER_ADDRESS, "1000000000000000000000000000");
    await iRinZToken.approve(process.env.RINZ_MARKET_ADDRESS,"1000000000000000000000000000");

    console.log("File: 4_set_up_market.js ~ RinZToken.approve", "Done");

    /***
     *      Buy market item on market
     *      @param {uint256} marketItemId
     *      @param {uint256} amount
     */
    await iRinZNFTMarket.buy(0, 1);

    console.log("File: 4_set_up_market.js ~ RinZNFTMarket.buy", "Done");

    /***
     *   Check market item after buy
     *    @param {address} ownerAddress
     */
    marketItemOfNoo = await iRinZNFTMarket.getMarketItemsByOwner(process.env.NOO_PHUOC_THINH_NFT_ADDRESS);
    console.log("File: 4_set_up_market.js ~ marketItemOfNoo after buy", marketItemOfNoo);

    /***
     *   Get market item of buyer after buy
     *    @param {address} ownerAddress
     */
    let marketItemOfBuyer = await iRinZNFTMarket.getMarketItemsByOwner(process.env.OWNER_ADDRESS);
    console.log("File: 4_set_up_market.js ~ marketItemOfBuyer", marketItemOfBuyer);
}
