// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { Signer } from "@ethersproject/abstract-signer";
import { ethers, waffle } from "hardhat";
import { Contract, ContractFactory } from "ethers";

import NFTArtifact from "../artifacts/contracts/NFT.sol/NFT.json";
import SOLOSArtifact from "../artifacts/contracts/SolosToken.sol/Solos.json";
import TimelockArtifact from "../artifacts/contracts/Timelock.sol/Timelock.json";
import VaultArtifact from "../artifacts/contracts/Vault.sol/Vault.json";

import { NFT } from "../typechain/NFT";
import { Solos } from "../typechain/Solos";
import { Timelock } from "../typechain/Timelock";
import { Vault } from "../typechain/Vault";
import { sign } from "crypto";
import { TASK_COMPILE_SOLIDITY_RUN_SOLCJS } from "hardhat/builtin-tasks/task-names";

const { deployContract } = waffle;

async function main(): Promise<void> {
  // Hardhat always runs the compile task when running scripts through it.
  // If this runs in a standalone fashion you may want to call compile manually
  // to make sure everything is compiled
  // await run("compile");

  const admin = "0xE8D848debB3A3e12AA815b15900c8E020B863F31";
  const uriSigner = "0xE8D848debB3A3e12AA815b15900c8E020B863F31";
  const timelockDelay = 259200;
  const vaultMembers = ["0xE8D848debB3A3e12AA815b15900c8E020B863F31"];
  const vaultShares = [100];

  const baseURI = "www.dennisonbertram.com";
  const maxTokenCount = 20000;
  const paymentSteps = [
    ethers.utils.parseUnits("0.1", 18),
    ethers.utils.parseUnits("0.3", 18),
    ethers.utils.parseUnits("0.5", 18),
    ethers.utils.parseUnits("0.9", 18),
    ethers.utils.parseUnits("1.7", 18),
    ethers.utils.parseUnits("3", 18),
    ethers.utils.parseUnits("5", 18),
    ethers.utils.parseUnits("100", 18),
  ];

  const signers: Signer[] = await ethers.getSigners();
  console.log("Signer Address: ", await signers[0].getAddress());

  // Deploy the NFT
  const nft = (await deployContract(signers[0], NFTArtifact, [])) as NFT;
  console.log("NFT deployed to: ", nft.address);

  // Deploy the ERC20 Token
  const solos = (await deployContract(signers[0], SOLOSArtifact, [nft.address])) as Solos;
  console.log("Solos deployed to: ", solos.address);

  // Deploy the Timelock
  const timelock = (await deployContract(signers[0], TimelockArtifact, [admin, timelockDelay])) as Timelock;
  console.log("Timelock deployed to: ", timelock.address);

  // Deploy the Vault
  const vault = (await deployContract(signers[0], VaultArtifact, [vaultMembers, vaultShares])) as Vault;
  console.log("Vault deployed to: ", vault.address);

  // is initialized:
  console.log("Is Contract Initialized: ", await nft.isInitialized());
  // Initialize the NFT
  await nft.initialize(baseURI, maxTokenCount, vault.address, uriSigner, solos.address, paymentSteps, timelock.address);
  console.log("Is Contract Initialized: ", await nft.isInitialized());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
