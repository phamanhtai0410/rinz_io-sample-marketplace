// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RinZNFTDetail.sol";

//contract OwnableDelegateProxy { }

//contract ProxyRegistry {
//    mapping(address => OwnableDelegateProxy) public proxies;
//}

contract RinZCampaign is ERC1155, Ownable {

    using RinZNFTDetail for RinZNFTDetail.NFTDetail;

    //address proxyRegistryAddress;
    string baseMetadataURI = "https://ipfs.io/ipfs/bafybeigpj4wn535qs7tttmc7rbhukgo4rpklxode43yfurhrlmbdchnwba/";
    uint256 private _currentTokenID = 0;
    mapping (uint256 => address) public campaigns;       // Mapping token Id to creators address (KOLAddress)
    mapping (uint256 => uint256) public tokenSupply;
    mapping (address => uint256[]) public holders;       // Mapping token's holder address to tokenIds list

    /**
   * @dev Require msg.sender to be the creator of the token id
   */
    modifier creatorOnly(uint256 _id) {
        require(campaigns[_id] == msg.sender, "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED");
        _;
    }

    /**
   * @dev Require msg.sender to own more than 0 of the token id
   */
    modifier ownersOnly(uint256 _id) {
        require(balanceOf(msg.sender, _id) > 0, "ERC1155Tradable#ownersOnly: ONLY_OWNERS_ALLOWED");
        _;
    }

    constructor() ERC1155("") {}

    function uri(uint256 _tokenid) override public view returns (string memory) {
        return string(
            abi.encodePacked(
                baseMetadataURI,
                Strings.toString(_tokenid),
                ".json"
            )
        );
    }

    function getNftByOwner(address owner) external view returns (RinZNFTDetail.NFTDetail[] memory) {
        uint256[] memory ids = holders[owner];
        RinZNFTDetail.NFTDetail[] memory nfts = new RinZNFTDetail.NFTDetail[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 amountOfIdUserOwner = balanceOf(owner, ids[i]);

            if (amountOfIdUserOwner <= 0) continue;

            RinZNFTDetail.NFTDetail memory nftDetail;

            nftDetail.nftAddress = campaigns[ids[i]];
            nftDetail.tokenId = ids[i];
            nftDetail.amount = balanceOf(owner, ids[i]);
            nftDetail.uri = uri(ids[i]);
            nfts[i] = nftDetail;
        }
        return nfts;
    }

    function sendNft(address from, address to, uint256 tokenId, uint256 amount, bytes memory data) external {
        // require(boxDetail.owner_by == from, "Token not owned");
    
        safeTransferFrom(from, to, tokenId, amount, data);
        _removeTokenIdIfNotHave(from);
        _addTokenIdToHolder(to, tokenId);
        // emit SendNft(from, to, tokenId, amount, data);
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
   * @dev Will update the base URL of token's URI
   * @param _newBaseMetadataURI New base URL of token's URI
   */
    function setBaseMetadataURI(
        string memory _newBaseMetadataURI
    ) public onlyOwner {
        baseMetadataURI = _newBaseMetadataURI;
    }

    /**
   * @dev Creates a new token type and assigns _initialSupply to an address
    * NOTE: remove onlyOwner if you want third parties to create new tokens on your contract (which may change your IDs)
    * @param _initialOwner address of the first owner of the token
    * @param _initialSupply amount to supply the first owner
    * @param _uri Optional URI for this token type
    * @param _data Data to pass if receiver is contract
    * @return The newly created token ID
    */
    function create(
        address _initialOwner,
        uint256 _initialSupply,
        string calldata _uri,
        bytes calldata _data
    ) external onlyOwner returns (uint256) {

        uint256 _id = _getNextTokenID();
        _incrementTokenTypeId();
        campaigns[_id] = _initialOwner;

        if (bytes(_uri).length > 0) {
            emit URI(_uri, _id);
        }

        _mint(_initialOwner, _id, _initialSupply, _data);
        tokenSupply[_id] = _initialSupply;

        uint256[] storage ids = holders[_initialOwner];
        ids.push(_id);

        return _id;
    }

    /**
    * @dev Mints some amount of tokens to an address
    * @param _to          Address of the future owner of the token
    * @param _id          Token ID to mint
    * @param _quantity    Amount of tokens to mint
    * @param _data        Data to pass if receiver is contract
    */
    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public creatorOnly(_id) {
        _mint(_to, _id, _quantity, _data);
        tokenSupply[_id] = tokenSupply[_id] + _quantity;
    }

    /**
      * @dev Mint tokens for each id in _ids
    * @param _to          The address to mint tokens to
    * @param _ids         Array of ids to mint
    * @param _quantities  Array of amounts of tokens to mint per id
    * @param _data        Data to pass if receiver is contract
    */
    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(campaigns[_id] == msg.sender, "ERC1155Tradable#batchMint: ONLY_CREATOR_ALLOWED");
            uint256 quantity = _quantities[i];
            tokenSupply[_id] = tokenSupply[_id] + quantity;
        }
        _mintBatch(_to, _ids, _quantities, _data);
    }

    /**
      * @dev Change the creator address for given tokens
    * @param _to   Address of the new creator
    * @param _ids  Array of Token IDs to change creator
    */
    function setCreator(
        address _to,
        uint256[] memory _ids
    ) public {
        require(_to != address(0), "ERC1155Tradable#setCreator: INVALID_ADDRESS.");
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            _setCreator(_to, id);
        }
    }

    /**
   * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-free listings.
   */
/*    function isApprovedForAll(
        address _owner,
        address _operator
    ) override public view returns (bool isOperator) {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(_owner)) == _operator) {
            return true;
        }

        return ERC1155.isApprovedForAll(_owner, _operator);
    }
*/

    function _removeTokenIdIfNotHave(
        address owner
    ) internal {
        uint256[] storage ids = holders[owner];

        for (uint256 i; i < ids.length; ++i) {
            if (balanceOf(owner, ids[i]) <= 0) {
                // Remove token id from holder
                ids[i] = ids[ids.length-1];
                ids.pop();
            }
        }
    }

    function _addTokenIdToHolder(
        address holderAddress,
        uint256 tokenId
    ) internal {
        uint256[] storage ids = holders[holderAddress];

        if (!_isHolderHaveTokenId(holderAddress, tokenId) && balanceOf(holderAddress, tokenId) > 0) {
            ids.push(tokenId);
        }
    }

    function _isHolderHaveTokenId (address holderAddress, uint256 tokenId) internal view returns (bool) {
        uint256[] storage ids = holders[holderAddress];

        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == tokenId) return true;
        }

        return false;
    }

    /**
      * @dev Change the creator address for given token
    * @param _to   Address of the new creator
    * @param _id  Token IDs to change creator of
    */
    function _setCreator(address _to, uint256 _id) internal creatorOnly(_id)
    {
        campaigns[_id] = _to;
    }

    /**
      * @dev Returns whether the specified token exists by checking to see if it has a creator
    * @param _id uint256 ID of the token to query the existence of
    * @return bool whether the token exists
    */
    function _exists(
        uint256 _id
    ) internal view returns (bool) {
        return campaigns[_id] != address(0);
    }

    /**
      * @dev calculates the next token ID based on value of _currentTokenID
    * @return uint256 for the next token ID
    */
    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID + 1;
    }

    /**
      * @dev increments the value of _currentTokenID
    */
    function _incrementTokenTypeId() private  {
        _currentTokenID++;
    }
}
