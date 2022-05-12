/**
 *  Init used packages
 */

const fs = require("fs");


/**
 * Init compiled contracts artifacts
 */
const NFTBox = artifacts.require("NFTBox");
const coinToken = artifacts.require("coinToken");


/**
 * Declares flags for:
 * 1. Re-deploy or Deploy New ?
 */
const DEPLOY_NEW_NFT_BOX = true;
const DEPLOY_NEW_coin_Token = true;


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
    console.log("*** Deployer Address: ", deployer.address)
    
    // Load address from .env fiel
    require('dotenv').config();
    const owner = process.env.OwnerAddress;
    

    /**
     * Deploy _coinToken to add to NFTBox
     */
    if (DEPLOY_NEW_coin_Token) {
        await deployer.deploy(coinToken);
        var iCoinToken = await coinToken.deployed();
        wf("iCoinToken", iCoinToken.address);
    } else {
        var iCoinToken = await coinToken.at(process.env.coinToken);
    }
    console.log("File: 2_core_step.js ~ iCoinToken", iCoinToken);


    /**
     * Deploy NFTBox
     */
    if (DEPLOY_NEW_NFT_BOX) {
        await deployer.deploy(NFTBox);
        var iNFTBox = await NFTBox.deployed();
        wf("iNFTBox", iNFTBox.address);
        await iNFTBox.initialize(iCoinToken.address);
    } else {
        var iNFTBox = await NFTBox.at(process.env.iNFTBox);
    }
    console.log("File: 2_core_step.js ~ iNFTBox: ", iNFTBox);


    /**
     * Set up to prepare NFTBox
     */

    
}