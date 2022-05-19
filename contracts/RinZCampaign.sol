// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RinZNFTDetail.sol";
import "./RinZNFTTypeDetail.sol";

contract RinZCampaign is ERC1155, Ownable {

    using RinZNFTDetail for RinZNFTDetail.NFTDetail;
    using RinZNFTTypeDetail for RinZNFTTypeDetail.NFTTypeDetail;
    using Counters for Counters.Counter;

    // bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    // bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event ActiveGiftCode(address to, uint16 tokenId, uint8 tokenType, string uri, string giftCode, bytes data);
    event Mint(address to, uint16 tokenId, uint8 tokenType, string uri, bytes data, uint256 kolProfit, uint256 marketFee);
    event CreateNFTTypeDetail(uint8 tokenType, uint256 totalSupply, uint256 pricePerItem);

    // token decimal
     uint public constant TOKEN_DECIMAL = 10 ** 18;

    // Market place owner address to receive market fee when mint token
    address marketOwnerAddress;

    // Campaign Payment Address to receive when mint token
    address campaignPaymentAddress;

    // Base uri of metadata of each tokenId
    string baseMetadataURI;

    // If true tokenId will set by minner
    bool isFixedTokenId;
    
    // Start time to buy first nft on this campaign
    uint256 startTimeToBuy;
    // End time to buy first nft on this campaign
    uint256 endTimeToBuy;

    // Currency use to buy first nft of this campaign
    IERC20 public coinToken;

    // symbol of this campaign
    string public symbol;

    Counters.Counter public tokenIdCounter;

    Counters.Counter public typeCounter;

    // custom token Ids list
    mapping (uint16 => bool) customTokenIdsWhiteList;

    // Mapping token type to campaign detail on this campaign
    mapping (uint8 => RinZNFTTypeDetail.NFTTypeDetail) public nftTypeDetails;

    // Mapping token type to rate of openBox action
    mapping (uint8 => uint16) public openBoxRates;

    // Mapping token type to supply have minted
    mapping (uint8 => uint256) public nftTypeSupply;

    // Mapping token's holder address to tokenIds list  
    mapping (address => uint16[]) public holders;   

    // Mapping token id to token type
    mapping (uint16 => uint8) public tokenIdsByType; 

    // Mapping from token ID to token details.
    mapping(uint16 => RinZNFTDetail.NFTDetail) public tokenDetails;

    // Mapping gift code is active
    mapping (string => bool) public giftCodes;

    constructor(
        address _marketOwnerAddress,
        address _campaignPaymentAddress,
        string memory _baseMetadataURI, 
        bool _isFixedTokenId, 
        uint256 _startTimeToBuy,
        uint256 _endTimeToBuy,
        IERC20 _coinToken,
        string memory _symbol
        ) ERC1155("") {
        //__AccessControl_init();
        marketOwnerAddress = _marketOwnerAddress;
        campaignPaymentAddress = _campaignPaymentAddress;
        baseMetadataURI = _baseMetadataURI;
        isFixedTokenId = _isFixedTokenId;
        startTimeToBuy = _startTimeToBuy;
        endTimeToBuy = _endTimeToBuy;
        coinToken = _coinToken;
        symbol = _symbol;

        //_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        //_setupRole(UPGRADER_ROLE, msg.sender);
    }

    function getSymbol() external view returns (string memory) {
        return symbol;
    }

    function customTokenIdToWhiteList(uint16 _tokenId, bool _isActive) public onlyOwner {
        customTokenIdsWhiteList[_tokenId] = _isActive;
    }

    function tokenIdIsInWhiteList(uint16 _tokenId) public view onlyOwner returns(bool) {
        return customTokenIdsWhiteList[_tokenId];
    }

    function createNFTTypeDetail(uint256 _totalSupply, uint256 _pricePerItem, bool isBox) public onlyOwner {
        RinZNFTTypeDetail.NFTTypeDetail memory _nftTypeDetail;
        
        uint8 nftType;
        
        if (isBox) nftType = 0; // typeId of box is 0
        else {
            typeCounter.increment();
            nftType = uint8(typeCounter.current());
        }
        _nftTypeDetail.nftType = nftType;
        _nftTypeDetail.totalSupply = _totalSupply;
        _nftTypeDetail.pricePerItem = _pricePerItem * TOKEN_DECIMAL;

        nftTypeDetails[nftType] = _nftTypeDetail;

        emit CreateNFTTypeDetail(nftType, _totalSupply, _pricePerItem);
    }

    function createOpenBoxRate(uint8[] memory _tokenType, uint16[] memory _rates) public onlyOwner {
        for (uint8 i = 0; i < _tokenType.length; i++) {
            openBoxRates[_tokenType[i]] = _rates[i];
        }
    }

    // Get metadata uri of tokenId
    function uri(uint256 _tokenId) override public view returns (string memory) {
        return string(
            abi.encodePacked(
                baseMetadataURI,
                Strings.toString(_tokenId),
                ".json"
            )
        );
    }

    // Get all nft by owner
    function getNftByOwner(address _owner) external view returns (RinZNFTDetail.NFTDetail[] memory) {
        uint16[] memory ids = holders[_owner];
        RinZNFTDetail.NFTDetail[] memory nfts = new RinZNFTDetail.NFTDetail[](ids.length);
        for (uint16 i = 0; i < ids.length; ++i) {
            uint256 amountOfIdUserOwner = balanceOf(_owner, uint256(ids[i]));

            if (amountOfIdUserOwner <= 0) continue;

            RinZNFTDetail.NFTDetail memory nftDetail;

            nftDetail.tokenId = ids[i];
            nftDetail.tokenType = tokenIdsByType[ids[i]];
            nftDetail.quantity = balanceOf(_owner, uint256(ids[i]));
            nftDetail.uri = uri(uint256(ids[i]));
            nfts[i] = nftDetail;
        }
        return nfts;
    }

    /**
      * @dev Mint tokens for id defined (first buy on market)
    * @param _to          The address to mint tokens to
    * @param _tokenId     Id to mint
    * @param _tokenType   Type of token to mint - if box tokenType is 0
    * @param _data        Data to pass if receiver is contract
    */
    function mint(
        address _to,
        uint16 _tokenId,
        uint8 _tokenType,
        bytes memory _data
    ) external {
        // Check time to buy
        require(block.timestamp >= startTimeToBuy, "It's not time to buy");
        require(block.timestamp <= endTimeToBuy, "It's not time to buy");
        
        // Check token type is exist in this campaign
        RinZNFTTypeDetail.NFTTypeDetail memory nftTypeDetail = nftTypeDetails[_tokenType];
        require(nftTypeDetail.totalSupply > 0, "Token type is not exist");
        
        // Check token type supply
        uint256 nftTypeHaveMinted = nftTypeSupply[_tokenType];
        require(nftTypeDetail.totalSupply > nftTypeHaveMinted, "Token run out");

        // If not fixed token id, id is auto increment
        if (!isFixedTokenId) {
            tokenIdCounter.increment();
            _tokenId = uint16(tokenIdCounter.current());
        } else {
            // require custom token id in white list
            require(_isCustomTokenIdExist(_tokenId), "Token id isn't in whitelist");
        }

        // Check token id is minted
        RinZNFTDetail.NFTDetail memory tokenDetail = tokenDetails[_tokenId];
        require(tokenDetail.quantity == 0, "Token id is minted");

        uint256 marketPlaceFee = _marketFee(nftTypeDetail.pricePerItem);
        // Fee for market
        coinToken.transferFrom(_to, marketOwnerAddress, marketPlaceFee);
        // Profit for the kol (total price - marketPlaceFee - discountFee)
        uint256 kolProfit = nftTypeDetail.pricePerItem - marketPlaceFee;
        coinToken.transferFrom(_to, campaignPaymentAddress, kolProfit);
            
        _mint(_to, uint256(_tokenId), 1, _data);
        
        // Update holders token ids
        _addTokenIdToHolder(_to, _tokenId);
        
        // Update nft type supply have minted
        nftTypeSupply[_tokenType] = nftTypeHaveMinted + 1;

        // Update token id by type
        tokenIdsByType[_tokenId] = _tokenType;

        string memory metaDataUri = uri(_tokenId);

        // Update list token id in campaign
        tokenDetail.tokenId = _tokenId;
        tokenDetail.tokenType = _tokenType;
        tokenDetail.quantity = 1;
        tokenDetail.uri = metaDataUri;

        tokenDetails[_tokenId] = tokenDetail;

        emit Mint(_to, _tokenId, _tokenType, metaDataUri, _data, kolProfit, marketPlaceFee);
    }

    /**
      * @dev Mint token for user have gift code
    * @param _to          The address to mint token to (dev Wallet)
    * @param _tokenId     Id to mint
    * @param _tokenType   Token type to mint
    * @param _data        Data to pass if receiver is contract
    * should update access control only dev or owner can call this function
    */
    function mintByGiftCode(address _to, uint16 _tokenId, uint8 _tokenType, string memory _giftCode, bytes memory _data) public onlyOwner {
        // Check time to buy
        require(block.timestamp >= startTimeToBuy, "It's not time to buy");
        require(block.timestamp <= endTimeToBuy, "It's not time to buy");

        // Check giftCode is activated
        require(!giftCodes[_giftCode], "Gift code is already activated");
        
        // Check token type is exist in this campaign
        RinZNFTTypeDetail.NFTTypeDetail memory nftTypeDetail = nftTypeDetails[_tokenType];
        require(nftTypeDetail.totalSupply > 0, "Token type is not exist");
        
        // Check token type supply
        uint256 nftTypeHaveMinted = nftTypeSupply[_tokenType];
        require(nftTypeDetail.totalSupply > nftTypeHaveMinted, "Token run out");

        // If not fixed token id, id is auto increment
        if (!isFixedTokenId) {
            tokenIdCounter.increment();
            _tokenId = uint16(tokenIdCounter.current());
        } 

        // Check token id is minted
        RinZNFTDetail.NFTDetail memory tokenDetail = tokenDetails[_tokenId];
        require(tokenDetail.quantity == 0, "Token id is minted");
            
        _mint(_to, uint256(_tokenId), 1, _data);
        
        // Update holders token ids
        _addTokenIdToHolder(_to, _tokenId);
        
        // Update nft type supply have minted
        nftTypeSupply[_tokenType] = nftTypeHaveMinted + 1;

        // Update token id by type
        tokenIdsByType[_tokenId] = _tokenType;

        string memory metaDataUri = uri(_tokenId);

        // Update list token id in campaign
        tokenDetail.tokenId = _tokenId;
        tokenDetail.tokenType = _tokenType;
        tokenDetail.quantity = 1;
        tokenDetail.uri = metaDataUri;

        tokenDetails[_tokenId] = tokenDetail;
        giftCodes[_giftCode] = true;

        emit ActiveGiftCode(_to, _tokenId, _tokenType, metaDataUri, _giftCode, _data);
    }

    // Remove tokenId of holder if not have (quantity < 1)
    function _removeTokenIdIfNotHave(
        address _owner
    ) internal {
        uint16[] storage ids = holders[_owner];

        for (uint256 i; i < ids.length; ++i) {
            if (balanceOf(_owner, uint256(ids[i])) <= 0) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
            }
        }
    }

    // Add tokenId to holder
    function _addTokenIdToHolder(
        address _holderAddress,
        uint16 _tokenId
    ) internal {
        uint16[] storage ids = holders[_holderAddress];

        if (!_isHolderHaveTokenId(_holderAddress, _tokenId) && balanceOf(_holderAddress, uint256(_tokenId)) > 0) {
            ids.push(_tokenId);
        }
    }

    // Check if holder have tokenId
    function _isHolderHaveTokenId (address _holderAddress, uint16 _tokenId) internal view returns (bool) {
        uint16[] storage ids = holders[_holderAddress];

        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == _tokenId) return true;
        }

        return false;
    }

    /** Marketplace fee */
    function _marketFee(uint256 _amount) internal pure returns (uint256 fee) {
        // TODO check rate
        fee = (_amount / 1000) * 45;
    }

    function _isCustomTokenIdExist(uint16 _tokenId) internal view returns (bool) {
        return customTokenIdsWhiteList[_tokenId];
    }
}
