// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./NFTBoxDetails.sol";
import "./INFTToken.sol";
import "./INFTBox.sol";

contract NFTBox is
    ERC721Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    IERC721Receiver,
    INFTBox
    {
    using NFTBoxDetails for NFTBoxDetails.BoxDetails;
    using Counters for Counters.Counter;

    event TokenCreated(address to, uint256 tokenId, uint256 details);
    event DeactiveSale(address to, uint256 tokenId, uint256 price);
    event Sale(address to, uint256 tokenId, uint256 price);
    event Buy(address to, uint256 tokenId, uint256 price, address owner_by);
    event OpenBox(address to, uint256 tokenId);
    event SendNft(address from, address to, uint256 tokenId);

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");

    uint public constant Token_DECIMALS = 10 ** 18;
    uint public constant MEGA_BOX = 3;
    uint public constant TOTAL_BOX = 8400;
    uint public constant NFT_EACH_BOX = 2;
    uint public constant MAX_OPEN_BOX_UNIT = 5;

    IERC20 public coinToken;
    INFTToken public luwaToken;
    Counters.Counter public tokenIdCounter;
    // Limit each common user to by.
    uint256 public boxLimit;
    // Box price in Token
    uint256 public boxPrice;
    bool public buyable;

    // Total box in whitelist pool
    uint256 public whiteListPool;
    uint256 public whiteListBought;

    // Mapping from owner address to token ID.
    mapping(address => uint256[]) public tokenIds;

    // Mapping from token ID to token details.
    mapping(uint256 => NFTBoxDetails.BoxDetails) public tokenDetails;

    // Mapping whitelist addresses to buyable amount
    mapping(address => uint256) public whiteList;

    // Mapping addresses to buyable amount
    mapping(address => uint256) public boughtList;

    /**
     * @notice Checks if the msg.sender is a contract or a proxy
     */
    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    function initialize(
        IERC20 coinToken_
    ) public initializer {
        __ERC721_init("Luwa Box", "LUBOX");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        coinToken = coinToken_;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(UPGRADER_ROLE, msg.sender);
        _setupRole(DESIGNER_ROLE, msg.sender);
        _setupRole(WHITELIST_ROLE, msg.sender);

        // Limit box each user can mint
        boxLimit = 5;
        boxPrice = 100 * Token_DECIMALS;
        buyable = false;
    }

    /** Marketplace fee */
    function marketFee(uint256 amount) internal pure returns (uint256 fee) {
        // TODO check rate
        fee = (amount / 1000) * 45;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        coinToken.transfer(msg.sender, coinToken.balanceOf(address(this)));
    }

    /** Burns a list of heroes. */
    function burn(uint256[] memory ids) external onlyRole(BURNER_ROLE) {
        for (uint256 i = 0; i < ids.length; ++i) {
            _burn(ids[i]);
        }
    }

    /** Sets boxLimit. */
    function setBoxLimit(uint256 boxLimit_) external onlyRole(DESIGNER_ROLE) {
        boxLimit = boxLimit_;
    }

    /** Box price in Token */
    function setBoxPrice(uint256 boxPrice_)
        external
        onlyRole(DESIGNER_ROLE)
    {
        boxPrice = boxPrice_ * Token_DECIMALS;
    }

    /** Disable for sale on marketplace */
    function deactiveSale(uint256 tokenId) external notContract {
        address to = msg.sender;
        NFTBoxDetails.BoxDetails storage boxDetail = tokenDetails[tokenId];
        require(boxDetail.owner_by == to, "Token not owned");
        require(boxDetail.is_opened == 0, "Box already opened");
        require(boxDetail.on_market == 1, "Box already off chain");
        boxDetail.on_market = 0;
        this.approve(to, tokenId);
        transferFrom(address(this), to, tokenId);
        emit DeactiveSale(to, tokenId, boxDetail.price);
    }

    /** Sets the design for open box to hero. */
    function setNFTToken(address contractAddress)
        external
        onlyRole(DESIGNER_ROLE)
    {
        luwaToken = INFTToken(contractAddress);
    }

    /** Enable common user mint box*/
    function setBuyable(bool isBuyable) external onlyRole(DESIGNER_ROLE) {
        buyable = isBuyable;
    }

    /** Set whitelist addresses and amount.
    If set after addr whitelistMint tokens, amount will be reset to input amount. */
    function setWhitelist(address addr, uint256 amount) external override onlyRole(WHITELIST_ROLE) {
        whiteList[addr] = amount;

        // If owner add addr to whitelist multiple time, whiteListPool will increase multiple time.
        whiteListPool += amount;
    }

    function getBoxIdsByOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory ids = tokenIds[owner];
        return ids;
    }

    function getBoxByOwner(address owner)
        external
        view
        returns (NFTBoxDetails.BoxDetails[] memory)
    {
        uint256[] memory ids = tokenIds[owner];
        NFTBoxDetails.BoxDetails[] memory boxes = new NFTBoxDetails.BoxDetails[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            NFTBoxDetails.BoxDetails memory boxDetail = tokenDetails[ids[i]];
            boxes[i] = boxDetail;
        }
        return boxes;
    }


    /** Mints tokens. */
    function mint(uint256 count) external notContract {
        require(count > 0, "No token to mint");

        require(tokenIdCounter.current() + count <= TOTAL_BOX, "Box sold out");

        // Check limit.
        address to = msg.sender;
        require(boughtList[to] + count <= boxLimit, "User limit buy reached");
        require(buyable == true, "Mint token have not start yet");

        address owner = address(this);
        // Transfer token
        coinToken.transferFrom(to, owner, boxPrice * count);

        for (uint256 i = 0; i < count; ++i) {
            uint256 id = tokenIdCounter.current();
            tokenIdCounter.increment();
            NFTBoxDetails.BoxDetails memory boxDetail;
            boxDetail.id = id;
            boxDetail.index = i;
            // TODO check default value
            boxDetail.price = 1000 * Token_DECIMALS;
            boxDetail.box_type = MEGA_BOX;
            boxDetail.on_market = 0;
            boxDetail.owner_by = to;
            tokenDetails[id] = boxDetail;
            _safeMint(to, id);
            emit TokenCreated(to, id, id);
        }

        boughtList[to] = boughtList[to] + count;
    }

    /** Whitelist mint tokens.*/
    function whitelistMint(uint256 count) external notContract {
        require(count > 0, "No token to mint");
        address to = msg.sender;
        require(whiteList[to] >= count, "User not in whitelist or limit reached");
        require(tokenIdCounter.current() + count <= TOTAL_BOX, "Box sold out");

        address owner = address(this);
        // Transfer token
        coinToken.transferFrom(to, owner, boxPrice * count);
        whiteList[to] -= count;

        for (uint256 i = 0; i < count; ++i) {
            uint256 id = tokenIdCounter.current();
            tokenIdCounter.increment();
            NFTBoxDetails.BoxDetails memory boxDetail;
            boxDetail.id = id;
            boxDetail.index = i;
            boxDetail.price = 1000 * Token_DECIMALS;
            boxDetail.box_type = MEGA_BOX;
            boxDetail.on_market = 0;
            boxDetail.owner_by = to;
            tokenDetails[id] = boxDetail;

            _safeMint(to, id);
            emit TokenCreated(to, id, id);
        }
        whiteListBought += count;
    }

    // Owner mint without transfer Token
    function ownerMint(uint256 count) external onlyRole(DESIGNER_ROLE) {
        require(count > 0, "No token to mint");
        address to = msg.sender;
        require(whiteList[to] >= count, "User not in whitelist or limit reached");
        require(tokenIdCounter.current() + count <= TOTAL_BOX, "Box sold out");

        //address owner = address(this);
        // Transfer token
        //coinToken.transferFrom(to, owner, boxPrice * count);
        whiteList[to] -= count;

        for (uint256 i = 0; i < count; ++i) {
            uint256 id = tokenIdCounter.current();
            tokenIdCounter.increment();
            NFTBoxDetails.BoxDetails memory boxDetail;
            boxDetail.id = id;
            boxDetail.index = i;
            boxDetail.price = 1000 * Token_DECIMALS;
            boxDetail.box_type = MEGA_BOX;
            boxDetail.on_market = 0;
            boxDetail.owner_by = to;
            tokenDetails[id] = boxDetail;

            _safeMint(to, id);
            emit TokenCreated(to, id, id);
        }
        whiteListBought += count;
    }

    /** Sale token */
    function sale(uint256 tokenId, uint256 boxPriceToken) external notContract {
        address to = msg.sender;
        require(ownerOf(tokenId) == to, "Token not owned");

        NFTBoxDetails.BoxDetails storage boxDetail = tokenDetails[tokenId];
        require(boxDetail.is_opened == 0, "Box already opened");
        boxDetail.price = boxPriceToken * Token_DECIMALS;
        boxDetail.on_market = 1;

        // Market hole token for sale
        transferFrom(to, address(this), tokenId);
        emit Sale(to, tokenId, boxDetail.price);
    }

    function buy(uint256 tokenId, uint256 price) external notContract {
        address to = msg.sender;
        //require(tokenIds[to].length + 1 <= boxLimit, "User limit reached");
        NFTBoxDetails.BoxDetails memory boxDetail = tokenDetails[tokenId];
        require(boxDetail.is_opened == 0, "Box already opened");
        require(boxDetail.on_market == 1, "Box not on chain for marketplace");
        require(price >= boxDetail.price, "Buy price is too low");

        require(boxDetail.price <= coinToken.balanceOf(to), "User need hold enough Token to buy this box");

        // Total fee
        uint256 fee = marketFee(boxDetail.price);

        // Fee for market
        coinToken.transferFrom(to, address(this), fee);

        // Fee for the owner
        coinToken.transferFrom(to, boxDetail.owner_by, boxDetail.price - fee);

        // Market hole token for sale
        this.approve(to, tokenId);
        transferFrom(address(this), to, tokenId);
        emit Buy(to, tokenId, boxDetail.price, boxDetail.owner_by);
    }


    /** Open box to NFTToken (NFT hero). Each box open 2 heros. */
    function openBox(uint256 tokenId) external notContract {
        address to = msg.sender;

        NFTBoxDetails.BoxDetails storage boxDetail = tokenDetails[tokenId];
        require(boxDetail.owner_by == to, "Token not owned");
        require(boxDetail.is_opened == 0, "Box already opened");
        require(boxDetail.on_market == 0, "Can not open box on the market");
        boxDetail.is_opened = 1;

        // Call NFTToken to random hero
        luwaToken.openBox(to, NFT_EACH_BOX, boxDetail.box_type);
        emit OpenBox(to, tokenId);
    }

    /** Open boxes to NFTToken (NFT hero). Each box open 2 heros. */
    function openBoxes(uint256[] calldata tokenIds_) external notContract {
        address to = msg.sender;
        require(tokenIds_.length <= MAX_OPEN_BOX_UNIT, "Open over maximun boxes each time.");

        for (uint256 i = 0; i < tokenIds_.length; ++i) {
            NFTBoxDetails.BoxDetails memory boxDetail = tokenDetails[tokenIds_[i]];
            require(boxDetail.owner_by == to, "Token not owned");
            require(boxDetail.is_opened == 0, "Box already opened");
            require(boxDetail.on_market == 0, "Can not open box on the market");
        }

        uint8 count;
        for (uint256 i = 0; i < tokenIds_.length; ++i) {
            NFTBoxDetails.BoxDetails storage boxDetail = tokenDetails[tokenIds_[i]];
            boxDetail.is_opened = 1;
            // Call NFTToken to random hero
            count += 1;
            emit OpenBox(to, tokenIds_[i]);
        }
        luwaToken.openBox(to, count * NFT_EACH_BOX, MEGA_BOX);
    }

    /** User can send tokens directly via d-app. */
    function sendNft(address to, uint256[] calldata tokenIds_) external {
        address from = msg.sender;

        for (uint256 i = 0; i < tokenIds_.length; ++i) {
            NFTBoxDetails.BoxDetails memory boxDetail = tokenDetails[tokenIds_[i]];
            require(boxDetail.owner_by == from, "Token not owned");
            require(boxDetail.is_opened == 0, "Box already opened");
            require(boxDetail.on_market == 0, "Can not send box on the market");
        }

        for (uint256 i = 0; i < tokenIds_.length; ++i) {
            safeTransferFrom(from, to, tokenIds_[i]);
            emit SendNft(from, to, tokenIds_[i]);
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        // Only transfer via this contract or from Design address
        // require(
        //     from == address(this) || to == address(this) || hasRole(DESIGNER_ROLE, address(from)),
        //     "Support sale/buy on market place only"
        // );
        NFTBoxDetails.BoxDetails storage boxDetail = tokenDetails[tokenId];
        require(boxDetail.is_opened == 0, "Box already opened");

        // Deactive box until owner active it again.
        if (from == address(this)) {
            boxDetail.on_market = 0;
            boxDetail.owner_by = to;
        }

        if (from != address(this) && to != address(this)) {
            // Only transfer token not on the market
            require(boxDetail.on_market == 0, "Can not send box on the market");
            boxDetail.owner_by = to;
        }

        ERC721Upgradeable._transfer(from, to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 id
    ) internal override {
        if (from == address(0)) {
            // Mint.
        } else {
            // Transfer or burn.
            // Swap and pop.
            uint256[] storage ids = tokenIds[from];
            NFTBoxDetails.BoxDetails storage boxDetail = tokenDetails[id];
            uint256 index = boxDetail.index;
            // Assign lastId to index to pop lastId.
            uint256 lastId = ids[ids.length - 1];
            ids[index] = lastId;
            ids.pop();

            // Update index after assign boxDetail to new index.
            NFTBoxDetails.BoxDetails storage boxDetailLastId = tokenDetails[
                lastId
            ];
            boxDetailLastId.index = index;
        }
        if (to == address(0)) {
            // Burn.
            delete tokenDetails[id];
        } else {
            // Transfer or mint.
            uint256[] storage ids = tokenIds[to];
            uint256 index = ids.length;
            ids.push(id);
            // Update index of boxDetail after push to the end of new user array
            NFTBoxDetails.BoxDetails storage boxDetail = tokenDetails[id];
            boxDetail.index = index;
            require(boxDetail.is_opened == 0, "Box already opened");
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @notice Checks if address is a contract
     * @dev It prevents contract from being targetted
     */
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
