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
        RinZCampaign,
        "https://ipfs.io/ipfs/bafybeibjvqmabyer3cmsrqc5d4lbonxkljytdsp5oecyo4pwxhr256b2dq/",
        false,
        1652758489
    );
    let iRinZQuobeeCampaign = await RinZCampaign.deployed();
    await deployer.deploy(
        RinZCampaign,
        "https://ipfs.io/ipfs/bafybeib2a2wmje5kyvcxnjnrfc4vikgy2dkql4lkb65pxwgdhibsahffve/",
        true,
        1654041600
    );
    let iRinZNooCampaign = await RinZCampaign.deployed();
    wf("QuobeeCampaign", iRinZQuobeeCampaign.address);
    wf("NooCampaign", iRinZNooCampaign.address);

    /**
     * Deploy RinZNFTMarket
     */

    await deployer.deploy(RinZNFTMarket);
    let iRinZNFTMarket = await RinZNFTMarket.deployed();
    wf("RinZNFTMarket", iRinZNFTMarket.address);

}
