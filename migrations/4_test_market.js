/**
 * Init compiled contracts artifacts
 */
const RinZToken = artifacts.require("RinZToken");
const RinZCampaign = artifacts.require("RinZCampaign");
const RinZNFTMarket = artifacts.require("RinZNFTMarket");

/**
 * Export migration scenario
 * @param {deployer} deployer
 */
module.exports = async function (deployer) {
    // Log deployer address
    console.log("*** Deployer Address: ", deployer.address);

    // Load address from .env file
    require('dotenv').config();


    let iRinZToken = await RinZToken.at(process.env.RINZ_TOKEN_ADDRESS);

    // console.log("File: 4_set_up_market.js ~ iRinZToken", iRinZToken);

    /**
     * Deploy RinZCampaign to add to RinZMarket and create new Campaign
     */

    let iRinZQuobeeCampaign = await RinZCampaign.at(process.env.RINZ_QUOBEE_CAMPAIGN_ADDRESS);
    let iRinZNooCampaign = await RinZCampaign.at(process.env.RINZ_NOO_CAMPAIGN_ADDRESS);

    // console.log("File: 3_test_market.js ~ iRinZQuobeeCampaign", iRinZQuobeeCampaign);
    // console.log("File: 3_test_market.js ~ iRinZNooCampaign", iRinZNooCampaign);

    /**
     * Deploy RinZNFTMarket
     */

    let iRinZNFTMarket = await RinZNFTMarket.at(process.env.RINZ_MARKET_ADDRESS);

    // console.log("File: 3_test_market.js ~ iRinZNFTMarket", iRinZNFTMarket);


    /***
     *      Setup to prepare RinZMarket
     */
    await iRinZNFTMarket.setCoinToken(process.env.RINZ_TOKEN_ADDRESS);
    console.log("File: 3_test_market.js ~ RinZToken set to RinZMarket");

    /***
     *   Approve to use RinZ token on market
     */
    await iRinZToken.approve(process.env.OWNER_ADDRESS, "1000000000000000000000000000");
    await iRinZToken.approve(process.env.RINZ_MARKET_ADDRESS,"1000000000000000000000000000");
    console.log("File: 3_test_market.js ~ RinZToken.approve", "Done");

    /***
     *     *** Only Owner ***
     *     Register Noo Campaign
     *     @param {address} campaignAddress
     *     @param {uint256} discountFee
     *     @param {address} paymentAddress
     */
    // await iRinZNFTMarket.campaignRegister(process.env.RINZ_NOO_CAMPAIGN_ADDRESS, 10, process.env.QUO_BEE_NFT_ADDRESS);
    // console.log("File: 3_test_market.js ~ Noo campaign registered");

    /***
     *     *** Only Owner ***
     *     Register Quobee Campaign
     *     @param {address} campaignAddress
     *     @param {uint256} discountFee
     *     @param {address} paymentAddress
     */
    await iRinZNFTMarket.campaignRegister(process.env.RINZ_QUOBEE_CAMPAIGN_ADDRESS, 3, process.env.QUO_BEE_NFT_ADDRESS);
    console.log("File: 3_test_market.js ~ Quobee campaign registered");


    /***
     *     Buy RinZCampaign
     *     Quobee campaign have token ids from 1 to 3
     *     Noo Phuoc Thinh have token ids from 2019 to 2020
     *     @param {address} owner
     *     @param {uint256} tokenId
     *     @param {uint256} quantity
     *     @param {string} data - Data of token, can be empty just this version
     */

    /***
     *     Fist buy noo phuoc thinh campaign
     *     @param {address} quobeeCampaignAddress
     *     @param {uint256} tokenId
     *     @param {uint256} pricePerItem
     *     @param {uint256} quantity
     */
    await iRinZNFTMarket.firstBuy(process.env.RINZ_QUOBEE_CAMPAIGN_ADDRESS, 2, "100000000000000000000", 1);

    /***
     *     Fist buy noo phuoc thinh campaign
     *     @param {address} nooPhuocThinhCampaignAddress
     *     @param {uint256} tokenId
     *     @param {uint256} pricePerItem
     *     @param {uint256} quantity
     */
    // await iRinZNFTMarket.firstBuy(process.env.RINZ_NOO_CAMPAIGN_ADDRESS, 2019, "100000000000000000000", 1);
    // console.log("File: 3_test_market.js ~ buy noo campaign done");

    /***
     *    Logs RinZCampaign of Noo Phuoc Thinh
     *    NOO_PHUOC_THINH_NFT_ADDRESS is the ownerAddress nft Noo Phuoc Thinh 2019
     *    @param {address} ownerAddress
     */
    // let nooPhuocThinhOwner = await iRinZNooCampaign.getNftByOwner(process.env.OWNER_ADDRESS);
    // console.log("File: 3_test_market.js ~ nooPhuocThinhCampaign", nooPhuocThinhOwner);

    /***
     *    Logs RinZCampaign of Quobee
     *    QUO_BEE_NFT_ADDRESS is the ownerAddress of nft Quobee 2
     *    @param {address} ownerAddress
     */
    let quobeeCampaignOwner = await iRinZQuobeeCampaign.getNftByOwner(process.env.OWNER_ADDRESS);
    console.log("File: 3_test_market.js ~ quobeeCampaignOwner", quobeeCampaignOwner);

    /***
     *    Approve to sale Noo Phuoc Thinh campaign on market
     */
    await iRinZQuobeeCampaign.setApprovalForAll(process.env.RINZ_MARKET_ADDRESS, true);
    console.log("File: 3_test_market.js ~ setApprovalForAll Quobee campaign Done");

    /***
     *    Sale Quobee nft (id 2) on market
     *    @param {address} campaignAddress
     *    @param {uint256} tokenId
     *    @param {uint256} pricePerItem
     *    @param {uint256} amount
     */
    await iRinZNFTMarket.sale(process.env.RINZ_QUOBEE_CAMPAIGN_ADDRESS, 2, 9, 1);
    console.log("File: 3_test_market.js ~ sale Quobee campaign on market Done");

    /***
     *   Check market item after sale
     *    @param {address} ownerAddress
     */
    let marketItems = await iRinZNFTMarket.getAllMarketItems();
    console.log("File: 3_test_market.js ~ marketItems", marketItems);

    /***
     *   Get market item of buyer after buy
     *    @param {address} ownerAddress
     */
    // let marketItemOfBuyer = await iRinZNFTMarket.getMarketItemsByOwner(process.env.OWNER_ADDRESS);
    // console.log("File: 4_set_up_market.js ~ marketItemOfBuyer", marketItemOfBuyer);
}
