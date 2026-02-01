/**
 * NeuralTrade AI - Deployment Script
 * Deploy smart contracts to Injective Protocol
 */

const hre = require("hardhat");

async function main() {
  console.log("\n🚀 Deploying NeuralTrade AI contracts to Injective...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  console.log("💰 Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString(), "wei\n");

  // Deploy TradingAgent
  console.log("📜 1/2 Deploying TradingAgent...");
  const TradingAgent = await hre.ethers.getContractFactory("TradingAgent");
  const tradingAgent = await TradingAgent.deploy(deployer.address);
  await tradingAgent.waitForDeployment();
  const tradingAgentAddress = await tradingAgent.getAddress();
  console.log("✅ TradingAgent deployed to:", tradingAgentAddress);

  // Deploy PortfolioManager
  console.log("\n📜 2/2 Deploying PortfolioManager...");
  const PortfolioManager = await hre.ethers.getContractFactory("PortfolioManager");
  const portfolioManager = await PortfolioManager.deploy(tradingAgentAddress);
  await portfolioManager.waitForDeployment();
  const portfolioManagerAddress = await portfolioManager.getAddress();
  console.log("✅ PortfolioManager deployed to:", portfolioManagerAddress);

  // Configure TradingAgent with PortfolioManager
  console.log("\n⚙️  Configuring TradingAgent...");
  const tx = await tradingAgent.setAuthorizedAI(portfolioManagerAddress, true);
  await tx.wait();
  console.log("✅ PortfolioManager authorized as AI agent");

  // Approve some common tokens
  console.log("\n💰 Approving common tokens...");
  const commonTokens = [
    "0xe28b3B32B6c345A34Ff64674606124Dd5Aceca30", // INJ (testnet)
    "0x...",
  ];

  for (const token of commonTokens) {
    try {
      await tradingAgent.setApprovedToken(token, true);
      console.log(`✅ Token ${token} approved`);
    } catch (e) {
      console.log(`⚠️  Token ${token} approval failed`);
    }
  }

  console.log("\n🎉 Deployment complete!\n");
  console.log("─────────────────────────────────────────────────────────────");
  console.log("Contract Addresses:");
  console.log("  TradingAgent:     ", tradingAgentAddress);
  console.log("  PortfolioManager: ", portfolioManagerAddress);
  console.log("─────────────────────────────────────────────────────────────\n");

  // Verify contracts (if on mainnet/testnet)
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("⏳ Waiting for block confirmations...");
    await tradingAgent.deploymentTransaction().wait(5);
    await portfolioManager.deploymentTransaction().wait(5);

    console.log("\n🔍 Verifying contracts...");
    try {
      await hre.run("verify:verify", {
        address: tradingAgentAddress,
        constructorArguments: [deployer.address],
      });
      console.log("✅ TradingAgent verified");
    } catch (e) {
      console.log("⚠️  TradingAgent verification failed:", e.message);
    }

    try {
      await hre.run("verify:verify", {
        address: portfolioManagerAddress,
        constructorArguments: [tradingAgentAddress],
      });
      console.log("✅ PortfolioManager verified");
    } catch (e) {
      console.log("⚠️  PortfolioManager verification failed:", e.message);
    }
  }

  console.log("\n📝 Add these to your .env file:");
  console.log(`TRADING_AGENT_ADDRESS=${tradingAgentAddress}`);
  console.log(`PORTFOLIO_MANAGER_ADDRESS=${portfolioManagerAddress}\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
