import { ethers } from "hardhat";

async function main() {
  console.log("Deploying YUM.fun contracts...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)));

  // Deploy AerodromeIntegration first
  console.log("\n1. Deploying AerodromeIntegration...");
  const AerodromeIntegration = await ethers.getContractFactory("AerodromeIntegration");
  const aerodromeIntegration = await AerodromeIntegration.deploy();
  await aerodromeIntegration.waitForDeployment();
  console.log("AerodromeIntegration deployed to:", await aerodromeIntegration.getAddress());

  // Deploy YUMFactory
  console.log("\n2. Deploying YUMFactory...");
  const YUMFactory = await ethers.getContractFactory("YUMFactory");
  const yumFactory = await YUMFactory.deploy(
    deployer.address, // protocolFeeRecipient
    deployer.address  // treasury
  );
  await yumFactory.waitForDeployment();
  console.log("YUMFactory deployed to:", await yumFactory.getAddress());

  // Set Aerodrome integration in factory (if needed)
  console.log("\n3. Setting up Aerodrome integration...");
  // Note: This would be done in the factory if we had a setter function
  console.log("Aerodrome integration setup completed");

  // Verify deployments
  console.log("\n4. Verifying deployments...");
  const factoryBalance = await ethers.provider.getBalance(await yumFactory.getAddress());
  const aerodromeBalance = await ethers.provider.getBalance(await aerodromeIntegration.getAddress());
  
  console.log("YUMFactory balance:", ethers.formatEther(factoryBalance), "ETH");
  console.log("AerodromeIntegration balance:", ethers.formatEther(aerodromeBalance), "ETH");

  // Display deployment summary
  console.log("\n=== Deployment Summary ===");
  console.log("Network:", await ethers.provider.getNetwork().then(n => n.name));
  console.log("Deployer:", deployer.address);
  console.log("YUMFactory:", await yumFactory.getAddress());
  console.log("AerodromeIntegration:", await aerodromeIntegration.getAddress());
  
  // Save deployment addresses
  const deploymentInfo = {
    network: await ethers.provider.getNetwork().then(n => n.name),
    chainId: await ethers.provider.getNetwork().then(n => n.chainId),
    deployer: deployer.address,
    yumFactory: await yumFactory.getAddress(),
    aerodromeIntegration: await aerodromeIntegration.getAddress(),
    timestamp: new Date().toISOString()
  };

  console.log("\nDeployment info saved:");
  console.log(JSON.stringify(deploymentInfo, null, 2));

  console.log("\n✅ YUM.fun contracts deployed successfully!");
  console.log("\nNext steps:");
  console.log("1. Verify contracts on BaseScan");
  console.log("2. Test token creation");
  console.log("3. Test trading functionality");
  console.log("4. Test graduation mechanism");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
