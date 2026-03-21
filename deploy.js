// scripts/deploy.js
const { ethers, run, network } = require("hardhat");
const fs = require("fs");

async function main() {

  // ── Step 1: Get deployer account ──────────────────────────
  const [deployer] = await ethers.getSigners();

  console.log("=".repeat(55));
  console.log("  Deploying FreelanceEscrow Smart Contract");
  console.log("=".repeat(55));
  console.log("Network        :", network.name);
  console.log("Deployer       :", deployer.address);

  // ── Step 2: Check balance ──────────────────────────────────
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Balance        :", ethers.formatEther(balance), "ETH");

  if (balance < ethers.parseEther("0.01")) {
    throw new Error(
      "Not enough ETH! Get Sepolia ETH from:\nhttps://sepoliafaucet.com"
    );
  }

  // ── Step 3: Deploy the contract ───────────────────────────
  console.log("\nDeploying contract...");

  const FreelanceEscrow = await ethers.getContractFactory("FreelanceEscrow");
  const escrow          = await FreelanceEscrow.deploy();

  await escrow.waitForDeployment();

  const contractAddress = await escrow.getAddress();
  const deployTx        = escrow.deploymentTransaction();

  console.log("\n" + "=".repeat(55));
  console.log("  Contract deployed successfully!");
  console.log("=".repeat(55));
  console.log("Contract address :", contractAddress);
  console.log("Transaction hash :", deployTx.hash);
  console.log("Block number     :", deployTx.blockNumber);

  // ── Step 4: Verify initial state ──────────────────────────
  const owner       = await escrow.owner();
  const platformFee = await escrow.platformFee();
  const jobCount    = await escrow.jobCount();

  console.log("\nInitial contract state:");
  console.log("  Owner        :", owner);
  console.log("  Platform fee :", platformFee.toString(), "bps");
  console.log("  Job count    :", jobCount.toString());

  // ── Step 5: Wait for confirmations ────────────────────────
  if (network.name !== "localhost" && network.name !== "hardhat") {
    console.log("\nWaiting for 5 block confirmations...");
    await deployTx.wait(5);
    console.log("Confirmed!");

    // ── Step 6: Verify on Etherscan ─────────────────────────
    console.log("\nVerifying on Etherscan...");
    try {
      await run("verify:verify", {
        address:              contractAddress,
        constructorArguments: [],
      });
      console.log("Verified on Etherscan!");
      console.log(
        "View contract: https://sepolia.etherscan.io/address/" + contractAddress
      );
    } catch (error) {
      if (error.message.toLowerCase().includes("already verified")) {
        console.log("Already verified!");
      } else {
        console.error("Verification failed:", error.message);
      }
    }
  }

  // ── Step 7: Save deployment info to JSON ──────────────────
  const deploymentInfo = {
    network:         network.name,
    contractAddress: contractAddress,
    deployer:        deployer.address,
    txHash:          deployTx.hash,
    blockNumber:     deployTx.blockNumber,
    platformFee:     platformFee.toString(),
    deployedAt:      new Date().toISOString(),
    etherscanUrl:    `https://sepolia.etherscan.io/address/${contractAddress}`,
  };

  fs.writeFileSync(
    "deployment.json",
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("\nDeployment info saved to deployment.json");
  console.log("=".repeat(55));
  console.log("DONE! Copy this address into your .env:");
  console.log("CONTRACT_ADDRESS=" + contractAddress);
  console.log("=".repeat(55));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\nDeployment FAILED:");
    console.error(error);
    process.exit(1);
  });