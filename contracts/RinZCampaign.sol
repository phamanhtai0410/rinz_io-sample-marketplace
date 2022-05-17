// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./RinZNFTDetail.sol";
import "./IRinZCampaign.sol";

contract RinZCampaign is ERC1155, Ownable, IRinZCampaign {

    using RinZNFTDetail for RinZNFTDetail.NFTDetail;
    using Counters for Counters.Counter;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event SendNft(address from, address to, uint256 tokenId, uint256 quantity, bytes data);
    event ActiveGiftCode(address to, uint256 tokenId, uint256 quantity, string uri, bytes data);
    event Mint(address to, uint256 tokenId, uint256 quantity, string uri, bytes data);

    // Base uri of metadata of each tokenId
    string baseMetadataURI;

    // If true tokenId will set by minner
    bool isFixedTokenId;
    
    // Start time to buy first nft on this campaign
    uint256 timeToBuy;

    Counters.Counter public tokenIdCounter;

    // Mapping tokenId to quantity of this token
    mapping (uint256 => uint256) public tokenSupply;  

    // Mapping token's holder address to tokenIds list  
    mapping (address => uint256[]) public holders;       

    // Mapping from token ID to token details.
    mapping(uint256 => RinZNFTDetail.NFTDetail) public tokenDetails;

    constructor(string memory baseMetadataURI_, bool isFixedTokenId_, uint256 timeToBuy_) ERC1155("") {
        //__AccessControl_init();
        baseMetadataURI = baseMetadataURI_;
        isFixedTokenId = isFixedTokenId_;
        timeToBuy = timeToBuy_;

        //_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        //_setupRole(UPGRADER_ROLE, msg.sender);
    }

    // Get metadata uri of tokenId
    function getUri(uint256 tokenId_) override public view returns (string memory) {
        return string(
            abi.encodePacked(
                baseMetadataURI,
                Strings.toString(tokenId_),
                ".json"
            )
        );
    }

    // Get quantity of tokenId owned by account
    function getBalanceOf(address account, uint256 tokenId) override public view returns (uint256) {
        return balanceOf(account, tokenId);
    }

    // Get all nft by owner
    function getNftByOwner(address owner) external view returns (RinZNFTDetail.NFTDetail[] memory) {
        uint256[] memory ids = holders[owner];
        RinZNFTDetail.NFTDetail[] memory nfts = new RinZNFTDetail.NFTDetail[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 amountOfIdUserOwner = balanceOf(owner, ids[i]);

            if (amountOfIdUserOwner <= 0) continue;

            RinZNFTDetail.NFTDetail memory nftDetail;

            nftDetail.tokenId = ids[i];
            nftDetail.quantity = balanceOf(owner, ids[i]);
            nftDetail.uri = getUri(ids[i]);
            nfts[i] = nftDetail;
        }
        return nfts;
    }

    // Send nft when buy and sale on marketplace
    function sendNft(address from, address to, uint256 tokenId, uint256 amount, bytes memory data) override external {
        require(_isHolderHaveTokenId(from, tokenId), "Token not owned");

        safeTransferFrom(from, to, tokenId, amount, data);
        _removeTokenIdIfNotHave(from);
        _addTokenIdToHolder(to, tokenId);

        emit SendNft(from, to, tokenId, amount, data);
    }

    /**
    * @dev Returns the total quantity for a token ID
    * @param _id uint256 ID of the token to query
    * @return amount of token in existence
    */
    function totalSupply(
        uint256 _id
    ) public view returns (uint256) {
        return tokenSupply[_id];
    }

    /**
      * @dev Mint tokens for each id in _ids
    * @param to          The address to mint tokens to
    * @param tokenIds    Array of ids to mint
    * @param quantities  Array of amounts of tokens to mint per id
    * @param data        Data to pass if receiver is contract
    */
    
    /*
    function batchMint(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        bytes memory data
    ) public {
        require(tokenIds.length == quantities.length, "TokenId and Quantities array must be the same length");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(quantities[i] > 0, "No token to mint");

            uint256 tokenId = tokenIds[i];
            uint256 quantity = quantities[i];
            tokenSupply[tokenId] = tokenSupply[tokenId] + quantity;
        }
        _mintBatch(to, tokenIds, quantities, data);
    }
    */
    

    /**
      * @dev Mint tokens for id defined (first buy on market)
    * @param to          The address to mint tokens to
    * @param tokenId     Id to mint
    * @param quantity    Array of amounts of tokens to mint per id
    * @param data        Data to pass if receiver is contract
    */
    function mint(
        address to,
        uint256 tokenId,
        uint256 quantity,
        bytes memory data
    ) override external {
        require(quantity > 0, "No token to mint");
        require(block.timestamp > timeToBuy, "It's not time to buy");

        // If not fixed token id, id is auto increment
        if (!isFixedTokenId) {
            tokenIdCounter.increment();
            tokenId = tokenIdCounter.current();
        } 
            
        _mint(to, tokenId, quantity, data);
        
        _addTokenIdToHolder(to, tokenId);
        tokenSupply[tokenId] = quantity;

        string memory uri = getUri(tokenId);
        emit Mint(to, tokenId, quantity, uri, data);
    }

    /**
      * @dev Mint token for user have gift code
    * @param to          The address to mint token to (dev Wallet)
    * @param tokenId     Id to mint
    * @param quantity    Array of amounts of tokens to mint per id
    * @param data        Data to pass if receiver is contract
    * should update access control only dev or owner can call this function
    */
    function mintByGiftCode(address to, uint256 tokenId, uint256 quantity, bytes memory data) external {
        require(quantity > 0, "No token to mint");

        if (!isFixedTokenId) {
            tokenIdCounter.increment();
            tokenId = tokenIdCounter.current();
        } 
        _mint(to, tokenId, quantity, data);
        _addTokenIdToHolder(to, tokenId);
        tokenSupply[tokenId] = quantity;

        string memory uri = getUri(tokenId);
        emit ActiveGiftCode(to, tokenId, quantity, uri, data);
    }

    // Remove tokenId of holder if not have (quantity < 1)
    function _removeTokenIdIfNotHave(
        address owner
    ) internal {
        uint256[] storage ids = holders[owner];

        for (uint256 i; i < ids.length; ++i) {
            if (balanceOf(owner, ids[i]) <= 0) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
            }
        }
    }

    // Add tokenId to holder
    function _addTokenIdToHolder(
        address holderAddress,
        uint256 tokenId
    ) internal {
        uint256[] storage ids = holders[holderAddress];

        if (!_isHolderHaveTokenId(holderAddress, tokenId) && balanceOf(holderAddress, tokenId) > 0) {
            ids.push(tokenId);
        }
    }

    // Check if holder have tokenId
    function _isHolderHaveTokenId (address holderAddress, uint256 tokenId) internal view returns (bool) {
        uint256[] storage ids = holders[holderAddress];

        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == tokenId) return true;
        }

        return false;
    }
}
