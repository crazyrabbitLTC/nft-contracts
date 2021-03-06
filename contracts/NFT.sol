// contracts/NFT.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/payment/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NFT is ERC721 {
    using Address for address payable;
    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bool public hasMintingFinished;
    address public presaleSigner;
    uint256 public presaleDelay;
    uint256 public launchBlock;
    uint256 public maxTokenCount;
    uint256 public basePrice;

    mapping(bytes32 => bool) public hasCouponBeenUsed;

    address payable public vault;
    address public governor;
    bool public isGovernorEnabled;
    address public buyoutOwner;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address _presaleSigner,
        uint256 _presaleDelay, // How many blocks after the sale gone live is reserved to presales
        uint256 _launchDelay, // How many blocks from deployment will the sale go live
        uint256 _maxTokenCount, // the maximum number of tokens that can be minted
        address _governor,
        address payable _vault
    ) ERC721(name, symbol) {
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

    }

    modifier onlyAfterPresale() {
        require(
            block.number >= launchBlock + presaleDelay,
            "Error: Presale is still ongoing"
        );
        _;
    }

    modifier paymentRequired() {
        // require that the user sends ether for purchase
        require(
            msg.value >= getCurrentPrice(),
            "Error: Payment required, or value below price"
        );
        _;
    }

    modifier isMintable() {
        // Require it is possible to still mint, IE: still more tokens
        require(!hasMintingFinished, "Error: Sale has finished");
        require(block.number >= launchBlock, "Error: sale has not yet started");
        require(
            _tokenIds.current() <= 9999,
            "Error: Maximum number of tokens have been minted"
        );
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == governor, "Error, call must come from governor");
        _;
    }

    function endMinting() public onlyGovernor {
        // End the mint
        _endMinting();
    }

    function buyout() public payable {
        require(
            msg.value >= getBuyoutPrice(),
            "Error: Buyout price not reached"
        );

        // End the mint
        _endMinting();
    }

    function mint() public payable isMintable paymentRequired onlyAfterPresale {
        // mint msg.sender token
        _mint(msg.sender);
    }

    function presaleMint(bytes32 hash, bytes memory signature)
        public
        payable
        isMintable
        paymentRequired
    {
        // Require the presale coupon
        require(
            !hasCouponBeenUsed[hash],
            "Error, presale coupoun has already been claimed"
        );
        require(
            presaleSigner == _recover(hash, signature),
            "Error: Not a valid Presale Coupon"
        );

        // Mark coupon as used
        hasCouponBeenUsed[hash] = true;

        // Mint msg.sender token
        _mint(msg.sender);
    }

    function _mint(address recipient) internal returns (uint256) {
        // Get current Item ID
        uint256 itemId = _tokenIds.current();

        // Mint user current ItemID
        _mint(recipient, itemId);

        // Increment id
        _tokenIds.increment();

        // Transfer value to the vault
        vault.sendValue(msg.value);

        // Return ItemId
        return itemId;
    }

    function updateBaseURI() public onlyGovernor {}

    function makePermanent() public {}

    function getCurrentPrice() public returns (uint256) {
        // use standard step function
    }

    function getBuyoutPrice() public returns (uint256) {}

    function _endMinting() private {
        // End the minting
        hasMintingFinished = true;
    }

    function _recover(bytes32 hash, bytes memory signature)
        public
        pure
        returns (address)
    {
        return hash.recover(signature);
    }

    function _toEthSignedMessageHash(bytes32 hash)
        public
        pure
        returns (bytes32)
    {
        return hash.toEthSignedMessageHash();
    }

}
