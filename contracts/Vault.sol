// contracts/NFT.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/payment/PaymentSplitter.sol";

contract Vault is PaymentSplitter {
    constructor(address[] memory artists, uint256[] memory artistShares) PaymentSplitter(artists, artistShares) {}
}
