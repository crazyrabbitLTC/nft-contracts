// contracts/NFT.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/payment/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address payable;
    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address payable public vault;
    address public uriSigner;
    address public timelock;

    bool public paused;
    bool public isInitialized = false;

    uint256 public maxTokenCount;
    uint256 public constant baseSolosPerUri = 4000 ether;

    IERC20 public solos;

    struct MINTER {
        address minter;
        uint256 tokenId;
        uint256 timestamp;
    }

    mapping(uint256 => MINTER) public minterLog;
    mapping(uint256 => string) public permanentURIIpfs;
    mapping(uint256 => string) public permanentURIArweave;

    mapping(address => bool) public activeArtist;
    mapping(uint256 => bool) public tokenURIClaimed;

    // Events
    event PermanentURIAdded(uint256 tokenId, string arweaveHash, string ipfsHash);
    event Payment(uint256 amount, address payer);
    event ArtistAdded(address artist);
    event ArtistRemoved(address artist);
    event Purchase(address recipient, uint256 value, uint256 token);
    event SolosReleased(address recipient, uint256 value);

    constructor() ERC721("SOLOS", "SOLOS") Ownable() {}

    modifier paymentRequired() {
        require(msg.value >= getCurrentPrice(), "Error: Payment required, or value below price");
        vault.sendValue(msg.value);
        _;
    }

    modifier isMintable() {
        require(!paused, "Error: Token minint has finished");
        require(_tokenIds.current() <= maxTokenCount, "Error: Maximum number of tokens have been minted");
        _;
    }

    modifier onlyArtist() {
        require(activeArtist[msg.sender], "Error: Artist is not active");
        _;
    }

    modifier onlyInitializeOnce() {
        require(!isInitialized, "Error: contract is already initialized");
        isInitialized = true;
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Error: caller is not timelock");
        _;
    }

    function initialize(
        string memory baseURI,
        uint256 _maxTokenCount, // the maximum number of tokens that can be minted
        address payable _vault,
        address _uriSigner,
        IERC20 _solos,
        address _timelock
    ) public onlyOwner onlyInitializeOnce {
        // Vote Token
        solos = _solos;

        // Set the base uri
        _setBaseURI(baseURI);

        uriSigner = _uriSigner;

        // Set minting status
        paused = false;

        // Set the maximum token count
        maxTokenCount = _maxTokenCount;

        // Set the vault
        vault = _vault;

        // Address of the timelock
        timelock = _timelock;
    }

    /**
     * Mint Functions
     */
    function mint() public payable isMintable paymentRequired returns (uint256) {
        uint256 tokenId = _mintToken(msg.sender);

        return tokenId;
    }

    function getCurrentPrice() public view returns (uint256) {
        return _getCurrentPrice();
    }

    function _getCurrentPrice() internal view returns (uint256) {
        if (totalSupply() >= 19990) {
            return 100000000000000000000; // 16381 - 16383 100 ETH
        } else if (totalSupply() >= 18750) {
            return 5000000000000000000; // 16000 - 16380 5.0 ETH
        } else if (totalSupply() >= 17500) {
            return 3000000000000000000; // 15000  - 15999 3.0 ETH
        } else if (totalSupply() >= 15000) {
            return 1700000000000000000; // 11000 - 14999 1.7 ETH
        } else if (totalSupply() >= 12500) {
            return 900000000000000000; // 7000 - 10999 0.9 ETH
        } else if (totalSupply() >= 10000) {
            return 500000000000000000; // 3000 - 6999 0.5 ETH
        } else if (totalSupply() >= 5000) {
            return 300000000000000000; // 3000 - 6999 0.3 ETH
        } else {
            return 100000000000000000; // 0 - 2999 0.1 ETH
        }
    }

    function artistMint() public isMintable onlyArtist returns (uint256) {
        // Artist does not get SoloS tokens for minting new works for free

        return _mintToken(msg.sender);
    }

    function _mintToken(address recipient) private returns (uint256) {
        // Get current Item ID
        uint256 tokenId = _tokenIds.current();

        // Log who bought the token and when
        minterLog[tokenId].minter = recipient;
        minterLog[tokenId].tokenId = tokenId;
        minterLog[tokenId].timestamp = block.timestamp;

        // Mint user current tokenId
        _mint(recipient, tokenId);

        // Increment id
        _tokenIds.increment();

        // Return tokenId
        return tokenId;
    }

    function createPermanentURI(
        bytes memory signature,
        string memory arweaveHash,
        string memory ipfsHash,
        uint256 tokenId
    ) public nonReentrant {
        // check to be sure this tokenID has not been claimed
        require(!tokenURIClaimed[tokenId], "Error: TokenId already claimed");
        tokenURIClaimed[tokenId] = true;

        // Give the minter a 1 week lead time to claim these tokens
        if (msg.sender != minterLog[tokenId].minter) {
            require(
                block.timestamp > minterLog[tokenId].timestamp + 1 days,
                "Error: Minters 1 day delay not yet expired"
            );
        }

        // Check the signature
        bytes32 assetHash = keccak256(abi.encodePacked(arweaveHash, tokenId));
        require(uriSigner == _recover(assetHash, signature), "Error: signature did not match");

        // Update the token URI
        permanentURIArweave[tokenId] = arweaveHash;
        permanentURIIpfs[tokenId] = ipfsHash;

        // TODO: update the URI on the underlying contract
        // _setTokenURI(tokenId, arweaveHash);
        // I am not convinced its safe to update the actual URI

        // Give users community Solos for this
        solos.transfer(msg.sender, baseSolosPerUri);

        // Make the Data permanently availible
        emit PermanentURIAdded(tokenId, arweaveHash, ipfsHash);
    }

    // Pause Art
    function pause(bool _paused) public onlyOwner {
        paused = _paused;
    }

    // Artist management
    function addArtist(address _artist) public onlyOwner {
        activeArtist[_artist] = true;
    }

    function removeArtist(address _artist) public onlyOwner {
        activeArtist[_artist] = false;
    }

    // Release solos that might be held by this contract
    function releaseSolos(address recipient, uint256 amount) public onlyTimelock {
        solos.transfer(recipient, amount);
        emit SolosReleased(recipient, amount);
    } // only timelock

    // Update Base URI
    function updateBaseURI(string memory baseURI) public onlyOwner  {
        _setBaseURI(baseURI);
    }

    receive() external payable {
        vault.sendValue(address(this).balance);
        emit Payment(msg.value, msg.sender);
    }

    // Signature recovery
    function _recover(bytes32 hash, bytes memory signature) public pure returns (address) {
        return hash.recover(signature);
    }

    function _toEthSignedMessageHash(bytes32 hash) public pure returns (bytes32) {
        return hash.toEthSignedMessageHash();
    }
}
