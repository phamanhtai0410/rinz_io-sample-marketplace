/**
 *  Init used packages
 */

const fs = require("fs");

/**
 * Init compiled contracts artifacts
 */
const RinZToken = artifacts.require("RinZToken");
const RinZCampaignFactory = artifacts.require("RinZCampaignFactory");
const RinZNFTMarket = artifacts.require("RinZNFTMarket");

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

    /**
     * Deploy RinZToken to add to RinZMarket
     */

    await deployer.deploy(RinZToken);
    let iRinZToken = await RinZToken.deployed();
    wf("RinZToken", iRinZToken.address);


    /**
     * Deploy RinZCampaign to add to RinZMarket and create new Campaign
     */

    await deployer.deploy(
        RinZCampaignFactory,
        "https://ipfs.io/ipfs/bafybeibjvqmabyer3cmsrqc5d4lbonxkljytdsp5oecyo4pwxhr256b2dq/",
        false,
        1652758489
    );
    let iRinZCampaignFactory = await RinZCampaignFactory.deployed();
    wf("RinZCampaignFactory", iRinZCampaignFactory.address);

    /**
     * Deploy RinZNFTMarket
     */
    await deployer.deploy(RinZNFTMarket);
    let iRinZNFTMarket = await RinZNFTMarket.deployed();
    wf("RinZNFTMarket", iRinZNFTMarket.address);

}
