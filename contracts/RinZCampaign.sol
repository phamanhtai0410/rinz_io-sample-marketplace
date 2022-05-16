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

contract RinZCampaign is 
            ERC1155, 
            Ownable, 
            IRinZCampaign
    {

    using RinZNFTDetail for RinZNFTDetail.NFTDetail;
    using Counters for Counters.Counter;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    string baseMetadataURI;
    bool isFixedTokenId;
    uint256 timeToBuy = 1654041600;
    Counters.Counter public tokenIdCounter;
    mapping (uint256 => uint256) public tokenSupply;
    mapping (address => uint256[]) public holders;       // Mapping token's holder address to tokenIds list

    // Mapping from token ID to token details.
    mapping(uint256 => RinZNFTDetail.NFTDetail) public tokenDetails;

    constructor(string memory baseMetadataURI_, bool isFixedTokenId_) ERC1155("") {
        //__AccessControl_init();
        baseMetadataURI = baseMetadataURI_;
        isFixedTokenId = isFixedTokenId_;

        //_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        //_setupRole(UPGRADER_ROLE, msg.sender);
    }

    function getUri(uint256 tokenId_) override public view returns (string memory) {
        return string(
            abi.encodePacked(
                baseMetadataURI,
                Strings.toString(tokenId_),
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

            nftDetail.tokenId = ids[i];
            nftDetail.amount = balanceOf(owner, ids[i]);
            nftDetail.uri = uri(ids[i]);
            nfts[i] = nftDetail;
        }
        return nfts;
    }

    function sendNft(address from, address to, uint256 tokenId, uint256 amount, bytes memory data) override external {
        require(_isHolderHaveTokenId(from, tokenId), "Token not owned");

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
      * @dev Mint tokens for each id in _ids
    * @param _to          The address to mint tokens to
    * @param _ids         Array of ids to mint
    * @param _quantities  Array of amounts of tokens to mint per id
    * @param _data        Data to pass if receiver is contract
    */
    /*
    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            uint256 quantity = _quantities[i];
            tokenSupply[_id] = tokenSupply[_id] + quantity;
        }
        _mintBatch(_to, _ids, _quantities, _data);
    }
    */

    /**
      * @dev Mint tokens for id defined (first buy on market)
    * @param _to          The address to mint tokens to
    * @param _id          Id to mint
    * @param _quantity    Array of amounts of tokens to mint per id
    * @param _data        Data to pass if receiver is contract
    */
    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) external {
        require(_quantity > 0, "No token to mint");
        require(block.timestamp > timeToBuy, "It's not time to buy");
        if (isFixedTokenId) {
            _mint(_to, _id, _quantity, _data);
        } else {
            tokenIdCounter.increment();
            _id = tokenIdCounter.current();
            _mint(_to, _id, _quantity, _data);
        }
        _addTokenIdToHolder(_to, _id);
        tokenSupply[_id] = _quantity;
    }

    /**
      * @dev Mint token for user have gift code
    * @param _to          The address to mint token to (dev Wallet)
    * @param _id          Id to mint
    * @param _quantity    Array of amounts of tokens to mint per id
    * @param _data        Data to pass if receiver is contract
    * should update access control only dev or owner can call this function
    */
    function mintByGiftCode(address _to, uint256 _id, uint256 _quantity, bytes memory _data) external {
        require(_quantity > 0, "No token to mint");
        _mint(_to, _id, _quantity, _data);
        _addTokenIdToHolder(_to, _id);
        tokenSupply[_id] = _quantity;
    }

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
}
