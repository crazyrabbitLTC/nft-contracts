// contracts/NFT.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/payment/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFT is ERC721 {
    using Address for address payable;
    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address payable public vault;
    address public governor;
    address public presaleSigner;
    address public exclusiveOwner;

    bool public hasMintingFinished;
    bool public isGovernorEnabled;
    bool public hasBeenBoughtOut;

    uint256 public presaleDelay;
    uint256 public launchBlock;
    uint256 public maxTokenCount;
    uint256 public basePrice;
    uint256 public buyoutPrice;
    uint256 public tokenPerMint;

    IERC20 public voteToken;

    mapping(bytes32 => bool) public hasCouponBeenUsed;
    mapping(uint256 => string) public permanentURI;

    // Events
    event EditionLimitSet(uint256 limit);
    event Fossilized(uint256 tokenId, string hash);

    constructor(
        string memory baseURI,
        address _presaleSigner,
        uint256 _presaleDelay, // How many blocks after the sale gone live is reserved to presales
        uint256 _launchDelay, // How many blocks from deployment will the sale go live
        uint256 _maxTokenCount, // the maximum number of tokens that can be minted
        uint256 _buyoutPrice,
        address _governor,
        address payable _vault,
        IERC20 _voteToken,
        uint256 _tokenPerMint
    ) ERC721("Solos-Saturnalia", "SSE") {

        // Vote Token
        voteToken = _voteToken;
        tokenPerMint = _tokenPerMint;

        // Set the base uri
        _setBaseURI(baseURI);

        // Set the lauch block
        launchBlock = block.number + _launchDelay;

        // Set the presale delay
        presaleDelay = _presaleDelay;

        //Set the presale signer address
        presaleSigner = _presaleSigner;

        // Set minting status
        hasMintingFinished = false;

        // Set the governor
        governor = _governor;

        // Set the maximum token count
        maxTokenCount = _maxTokenCount;

        // Set the vault
        vault = _vault;

        // Set the starting Buyout Price
        buyoutPrice = _buyoutPrice;
    }

    modifier onlyAfterPresale() {
        require(block.number >= launchBlock + presaleDelay, "Error: Presale is still ongoing");
        _;
    }

    modifier onlyExclusiveOwner() {
        require(msg.sender == exclusiveOwner, "Error: call must come from exclusive owner");
        _;
    }

    modifier paymentRequired() {
        // require that the user sends ether for purchase
        require(msg.value >= getCurrentPrice(), "Error: Payment required, or value below price");
        // Transfer value to the vault
        vault.sendValue(msg.value);
        _;
    }

    modifier isMintable() {
        // Require it is possible to still mint, IE: still more tokens
        require(!hasMintingFinished, "Error: Minting has finished");
        require(block.number >= launchBlock, "Error: sale has not yet started");
        require(_tokenIds.current() <= maxTokenCount, "Error: Maximum number of tokens have been minted");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == governor, "Error, call must come from governor");
        require(!hasBeenBoughtOut, "Error, series has been bought out");
        _;
    }

    /**
     * Mint Functions
     */
    function mint() public payable isMintable paymentRequired onlyAfterPresale returns (uint256) {
        // mint msg.sender token
        return _mintToken(msg.sender);
    }

    function exclusiveMinter() public onlyExclusiveOwner returns (uint256) {
        return _mintToken(msg.sender);
    }

    function presaleMint(bytes32 hash, bytes memory signature)
        public
        payable
        isMintable
        paymentRequired
        returns (uint256)
    {
        // Require the presale coupon
        require(!hasCouponBeenUsed[hash], "Error, presale coupoun has already been claimed");
        require(presaleSigner == _recover(hash, signature), "Error: Not a valid Presale Coupon");

        // Mark coupon as used
        hasCouponBeenUsed[hash] = true;

        // Mint msg.sender token
        return _mintToken(msg.sender);
    }

    function _mintToken(address recipient) private returns (uint256) {
        // Get current Item ID
        uint256 itemId = _tokenIds.current();

        // Mint user current ItemID
        _mint(recipient, itemId);

        // Increment id
        _tokenIds.increment();

        // Transfer a VoteToken to the user
        voteToken.transfer(msg.sender, 1 ether);

        // Return ItemId
        return itemId;
    }

    /**
     * Change Edition Settings
     */
    function changeEditionLimit(uint256 limit) public onlyGovernor {
        _changeEditionLimit(limit);
    }

    function exclusiveChangeEditionLimit(uint256 limit) public onlyExclusiveOwner {
        _changeEditionLimit(limit);
    }

    function _changeEditionLimit(uint256 limit) private {
        // End the mint
        maxTokenCount = limit;

        // Tell the world
        emit EditionLimitSet(limit);
    }

    function buyout() public payable {
        require(msg.value >= getBuyoutPrice(), "Error: Buyout price not reached");

        // Set the exclusive owner
        exclusiveOwner = msg.sender;

        // Set has been bought out
        hasBeenBoughtOut = true;

        // End the mint
        _endMinting();
    }

    function _endMinting() private {
        // End the minting
        hasMintingFinished = true;
    }

    function updateBaseURI(
        bytes memory signature,
        string memory ipfsHash,
        uint256 tokenId
    ) public {
        // Check the signature
        bytes32 assetHash = keccak256(abi.encodePacked(ipfsHash, tokenId));
        require(presaleSigner == _recover(assetHash, signature), "Error: signature did not match");

        // Update the token URI
        permanentURI[tokenId] = ipfsHash;

        // Make the Data permanently availible
        emit Fossilized(tokenId, ipfsHash);
    }

    function getCurrentPrice() public pure returns (uint256) {
        return 0.1 ether;
    }

    function getBuyoutPrice() public pure returns (uint256) {
        return 6666 ether;
    }

    // Signature recovery
    function _recover(bytes32 hash, bytes memory signature) public pure returns (address) {
        return hash.recover(signature);
    }

    function _toEthSignedMessageHash(bytes32 hash) public pure returns (bytes32) {
        return hash.toEthSignedMessageHash();
    }
}
