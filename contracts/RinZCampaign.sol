// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RinZNFTDetail.sol";
import "./RinZNFTTypeDetail.sol";
import "./INFTBox.sol";
import "./RinZNFTMarket.sol";

contract RinZCampaign is ERC1155, AccessControl {

    using RinZNFTDetail for RinZNFTDetail.NFTDetail;
    using RinZNFTTypeDetail for RinZNFTTypeDetail.NFTTypeDetail;
    using Counters for Counters.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //event ActiveGiftCode(address to, uint16 tokenId, uint8 tokenType, string uri, string giftCode, bytes data);
    event Mint(address to, uint16 tokenId, uint8 tokenType, string uri, uint256 kolProfit, uint256 marketFee);
    event CreateNFTTypeDetail(uint8 tokenType, uint256 totalSupply, uint256 pricePerItem);
    event OpenBox(address to, uint16 tokenId);

    // token decimal
     uint public constant TOKEN_DECIMAL = 10 ** 18;
    uint8 public constant MAX_OPEN_BOX_UNIT = 10;
    uint8 public constant NFT_PER_BOX = 1;

    // Market place owner address to receive market fee when mint token
    address marketOwnerAddress;

    // Campaign Payment Address to receive when mint token
    address campaignPaymentAddress;

    // If true tokenId will set by minner
    bool isFixedTokenId;
    
    // Start time to buy first nft on this campaign
    uint256 startTimeToBuy;
    // End time to buy first nft on this campaign
    uint256 endTimeToBuy;

    // Currency use to buy first nft of this campaign
    IERC20 public coinToken;

    INFTBox public nftBox;

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
        bool _isFixedTokenId, 
        uint256 _startTimeToBuy,
        uint256 _endTimeToBuy,
        IERC20 _coinToken,
        string memory _symbol,
        address _adminAddress
        ) ERC1155("") {
        //__AccessControl_init();
        marketOwnerAddress = _marketOwnerAddress;
        campaignPaymentAddress = _campaignPaymentAddress;
        isFixedTokenId = _isFixedTokenId;
        startTimeToBuy = _startTimeToBuy;
        endTimeToBuy = _endTimeToBuy;
        coinToken = _coinToken;
        symbol = _symbol;

        _setupRole(ADMIN_ROLE, _adminAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
    }

    function setCampaignPaymentAddress(address _campaignPaymentAddress) public onlyRole(ADMIN_ROLE) {
        campaignPaymentAddress = _campaignPaymentAddress;
    }

    function setCoinToken(IERC20 _coinToken) public onlyRole(ADMIN_ROLE) {
        coinToken = _coinToken;
    }

    function getSymbol() external view returns (string memory) {
        return symbol;
    }

    function customTokenIdToWhiteList(uint16 _tokenId, bool _isActive) public onlyRole(ADMIN_ROLE) {
        customTokenIdsWhiteList[_tokenId] = _isActive;
    }

    function tokenIdIsInWhiteList(uint16 _tokenId) public view onlyRole(ADMIN_ROLE) returns(bool) {
        return customTokenIdsWhiteList[_tokenId];
    }

    function createNFTTypeDetail(uint256 _totalSupply, uint256 _pricePerItem, bool isBox) public onlyRole(ADMIN_ROLE) {
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

    function createOpenBoxRate(uint8[] memory _tokenType, uint16[] memory _rates) public onlyRole(ADMIN_ROLE) {
        for (uint8 i = 0; i < _tokenType.length; i++) {
            openBoxRates[_tokenType[i]] = _rates[i];
        }
    }

    // Get metadata uri of tokenId
//    function uri(uint256 _tokenId) override public view returns (string memory) {
//        return string(
//            abi.encodePacked(
//                baseMetadataURI,
//                Strings.toString(_tokenId),
//                ".json"
//            )
//        );
//    }

    // Get all nft by owner
    function getNftByOwner(address _owner) external view returns (RinZNFTDetail.NFTDetail[] memory) {
        uint16[] memory ids = holders[_owner];
        RinZNFTDetail.NFTDetail[] memory nfts = new RinZNFTDetail.NFTDetail[](ids.length);
        for (uint16 i = 0; i < ids.length; ++i) {
            uint256 amountOfIdUserOwner = balanceOf(_owner, uint256(ids[i]));

            if (amountOfIdUserOwner <= 0) continue;

            RinZNFTDetail.NFTDetail memory nftDetail = tokenDetails[ids[i]];
            nfts[i] = nftDetail;
        }
        return nfts;
    }

    /**
      * @dev Mint tokens for id defined (first buy on market)
    * @param _tokenId       Id to mint
    * @param _tokenType     Type of token to mint - if box tokenType is 0
    * @param _metadataURI   Meta data uri of this token
    */
    function mint(
        uint16 _tokenId,
        uint8 _tokenType,
        string memory _metadataURI
    ) external {
        address _to = msg.sender;
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
            
        _mint(_to, uint256(_tokenId), 1, "");
        
        // Update holders token ids
        _addTokenIdToHolder(_to, _tokenId);
        
        // Update nft type supply have minted
        nftTypeSupply[_tokenType] = nftTypeHaveMinted + 1;

        // Update token id by type
        tokenIdsByType[_tokenId] = _tokenType;

        // Update list token id in campaign
        tokenDetail.tokenId = _tokenId;
        tokenDetail.tokenType = _tokenType;
        tokenDetail.quantity = 1;
        tokenDetail.uri = _metadataURI;
        tokenDetail.isOpened = _tokenType > 0;
        tokenDetail.owner = _to;

        tokenDetails[_tokenId] = tokenDetail;

        emit Mint(_to, _tokenId, _tokenType, _metadataURI, kolProfit, marketPlaceFee);
    }

    /**
      * @dev Mint token for user have gift code
    * @param _to                 The address to mint token to (dev Wallet)
    * @param _tokenId            Id to mint
    * @param _tokenType          Token type to mint
    * @param _metadataURI        Meta data uri of this token
    * should update access control only dev or owner can call this function
    */
    function mintByGiftCode(
        address _to,
        uint16 _tokenId, 
        uint8 _tokenType, 
        string memory _giftCode, 
        string memory _metadataURI
        ) 
            public
            onlyRole(ADMIN_ROLE) 
            returns (uint16)
        {
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
        } else {
            // require custom token id in white list
            require(_isCustomTokenIdExist(_tokenId), "Token id isn't in whitelist");
        }

        // Check token id is minted
        RinZNFTDetail.NFTDetail memory tokenDetail = tokenDetails[_tokenId];
        require(tokenDetail.quantity == 0, "Token id is minted");
            
        _mint(_to, uint256(_tokenId), 1, "");
        
        // Update holders token ids
        _addTokenIdToHolder(_to, _tokenId);
        
        // Update nft type supply have minted
        nftTypeSupply[_tokenType] = nftTypeHaveMinted + 1;

        // Update token id by type
        tokenIdsByType[_tokenId] = _tokenType;

        // Update list token id in campaign
        tokenDetail.tokenId = _tokenId;
        tokenDetail.tokenType = _tokenType;
        tokenDetail.quantity = 1;
        tokenDetail.uri = _metadataURI;
        tokenDetail.isOpened = _tokenType > 0;
        tokenDetail.owner = _to;

        tokenDetails[_tokenId] = tokenDetail;
        giftCodes[_giftCode] = true;

        return _tokenId;

        //emit ActiveGiftCode(_to, _tokenId, _tokenType, metaDataUri, _giftCode, _data);
    }

    function setNFTBox(address contractAddress) external onlyRole(ADMIN_ROLE)
    {
        nftBox = INFTBox(contractAddress);
    }

    /** Open box to NFTToken. */
    function openBox(uint16 _tokenId) external {
        address to = msg.sender;

        RinZNFTDetail.NFTDetail storage boxDetail = tokenDetails[_tokenId];
        require(boxDetail.owner == to, "Token not owned");
        require(!boxDetail.isOpened, "Box already opened");
        boxDetail.isOpened = true;

        // Call NFTBox to random token
        nftBox.openBox(to, 1);
        emit OpenBox(to, _tokenId);
    }

    /** Open boxes to NFTToken. */
    function openBoxes(uint16[] calldata _tokenIds) external {
        address to = msg.sender;
        require(_tokenIds.length <= MAX_OPEN_BOX_UNIT, "Open over maximum boxes each time.");

        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            RinZNFTDetail.NFTDetail memory boxDetail = tokenDetails[_tokenIds[i]];
            require(boxDetail.owner == to, "Token not owned");
            require(!boxDetail.isOpened, "Box already opened");
        }

        uint8 count;
        for (uint256 i = 0; i < _tokenIds.length; ++i) {
            RinZNFTDetail.NFTDetail storage boxDetail = tokenDetails[_tokenIds[i]];
            boxDetail.isOpened = true;

            count += 1;
            emit OpenBox(to, _tokenIds[i]);
        }
        nftBox.openBox(to, count * NFT_PER_BOX);
    }


    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
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
    function _marketFee(uint256 _amount) internal view returns (uint256 fee) {
        // TODO check rate
        uint16 marketFeePercent = RinZNFTMarket(marketOwnerAddress).getMarketFeePercent();
        fee = (_amount / 1000) * marketFeePercent;
    }

    function _isCustomTokenIdExist(uint16 _tokenId) internal view returns (bool) {
        return customTokenIdsWhiteList[_tokenId];
    }
}
