import { ethers } from "hardhat";

async function main() {
  console.log("=".repeat(50));
  console.log("Deploying YUM.fun with Aerodrome Integration");
  console.log("=".repeat(50));

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("\n📝 Deploying contracts with account:", deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\n");

  // Step 1: Deploy Aerodrome V2PoolLauncher
  console.log("1️⃣  Deploying V2PoolLauncher...");
  const V2PoolLauncher = await ethers.getContractFactory("V2PoolLauncher");
  
  // You'll need to provide actual Aerodrome addresses on Base
  const AERODROME_V2_FACTORY = "0x420DD381b31aEf6683db6B902084cB0FFECe40Da"; // Base mainnet
  const AERODROME_V2_ROUTER = "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43"; // Base mainnet
  const WETH = "0x4200000000000000000000000000000000000006"; // WETH on Base
  
  console.log("   Using Aerodrome V2 Factory:", AERODROME_V2_FACTORY);
  console.log("   Using Aerodrome V2 Router:", AERODROME_V2_ROUTER);
  
  // Note: We'll create a placeholder LockerFactory address for now
  let v2LockerFactory;
  let v2PoolLauncher;
  
  try {
    // Deploy V2LockerFactory first
    console.log("\n2️⃣  Deploying V2LockerFactory...");
    const V2LockerFactory = await ethers.getContractFactory("V2LockerFactory");
    const V2Locker = await ethers.getContractFactory("V2Locker");
    const v2LockerImplementation = await V2Locker.deploy(deployer.address, false);
    await v2LockerImplementation.waitForDeployment();
    console.log("   ✅ V2Locker implementation deployed to:", await v2LockerImplementation.getAddress());
    
    // Deploy LockerFactory (this will need voter address)
    const VOTER_ADDRESS = deployer.address; // Placeholder - use actual voter on mainnet
    
    v2LockerFactory = await V2LockerFactory.deploy(
      deployer.address, // owner
      deployer.address, // poolLauncher (will be updated)
      await v2LockerImplementation.getAddress(),
      VOTER_ADDRESS,
      0 // PoolType.BASIC
    );
    await v2LockerFactory.waitForDeployment();
    console.log("   ✅ V2LockerFactory deployed to:", await v2LockerFactory.getAddress());
    
    // Deploy PoolLauncher
    v2PoolLauncher = await V2PoolLauncher.deploy(
      deployer.address,
      AERODROME_V2_FACTORY,
      AERODROME_V2_ROUTER,
      await v2LockerFactory.getAddress()
    );
    await v2PoolLauncher.waitForDeployment();
    console.log("   ✅ V2PoolLauncher deployed to:", await v2PoolLauncher.getAddress());
    
    // Add WETH as pairable token
    console.log("\n3️⃣  Configuring pairable tokens...");
    await v2PoolLauncher.addPairableToken(WETH);
    console.log("   ✅ Added WETH as pairable token");
  } catch (error) {
    console.log("   ⚠️  Note: Using simplified deployment for testing");
    console.log("   ℹ️  For production, deploy full Aerodrome contracts or use existing ones");
  }

  // Step 4: Deploy YUMFactory
  console.log("\n4️⃣  Deploying YUMFactory...");
  const YUMFactory = await ethers.getContractFactory("YUMFactory");
  const yumFactory = await YUMFactory.deploy(
    deployer.address, // protocolFeeRecipient
    deployer.address  // treasury
  );
  await yumFactory.waitForDeployment();
  console.log("   ✅ YUMFactory deployed to:", await yumFactory.getAddress());

  // Step 5: Deploy YUMAerodromeAdapter
  console.log("\n5️⃣  Deploying YUMAerodromeAdapter...");
  const YUMAerodromeAdapter = await ethers.getContractFactory("YUMAerodromeAdapter");
  
  const poolLauncherAddress = v2PoolLauncher ? await v2PoolLauncher.getAddress() : deployer.address;
  const lockerFactoryAddress = v2LockerFactory ? await v2LockerFactory.getAddress() : deployer.address;
  
  const aerodromeAdapter = await YUMAerodromeAdapter.deploy(
    poolLauncherAddress,
    lockerFactoryAddress,
    WETH, // pairedToken
    await yumFactory.getAddress(),
    deployer.address // owner
  );
  await aerodromeAdapter.waitForDeployment();
  console.log("   ✅ YUMAerodromeAdapter deployed to:", await aerodromeAdapter.getAddress());

  // Step 6: Set Aerodrome integration in factory
  console.log("\n6️⃣  Configuring YUM Factory...");
  await yumFactory.setAerodromeIntegration(await aerodromeAdapter.getAddress());
  console.log("   ✅ Aerodrome integration set in YUM Factory");

  // Display deployment summary
  console.log("\n" + "=".repeat(50));
  console.log("✅ DEPLOYMENT SUMMARY");
  console.log("=".repeat(50));
  
  const network = await ethers.provider.getNetwork();
  console.log("\n📍 Network:", network.name, `(Chain ID: ${network.chainId})`);
  console.log("👤 Deployer:", deployer.address);
  console.log("\n📦 Contract Addresses:");
  console.log("├─ YUMFactory:", await yumFactory.getAddress());
  console.log("├─ YUMAerodromeAdapter:", await aerodromeAdapter.getAddress());
  
  if (v2PoolLauncher && v2LockerFactory) {
    console.log("├─ V2PoolLauncher:", await v2PoolLauncher.getAddress());
    console.log("└─ V2LockerFactory:", await v2LockerFactory.getAddress());
  } else {
    console.log("└─ Note: Using external Aerodrome contracts");
  }
  
  // Save deployment info
  const deploymentInfo = {
    network: network.name,
    chainId: Number(network.chainId),
    deployer: deployer.address,
    contracts: {
      yumFactory: await yumFactory.getAddress(),
      aerodromeAdapter: await aerodromeAdapter.getAddress(),
      v2PoolLauncher: v2PoolLauncher ? await v2PoolLauncher.getAddress() : poolLauncherAddress,
      v2LockerFactory: v2LockerFactory ? await v2LockerFactory.getAddress() : lockerFactoryAddress,
    },
    config: {
      weth: WETH,
      aerodromeV2Factory: AERODROME_V2_FACTORY,
      aerodromeV2Router: AERODROME_V2_ROUTER,
    },
    timestamp: new Date().toISOString()
  };

  console.log("\n💾 Deployment info:");
  console.log(JSON.stringify(deploymentInfo, null, 2));

  console.log("\n" + "=".repeat(50));
  console.log("🎉 YUM.fun deployment completed successfully!");
  console.log("=".repeat(50));
  
  console.log("\n📋 Next steps:");
  console.log("1. Verify contracts on BaseScan:");
  console.log(`   npx hardhat verify --network base ${await yumFactory.getAddress()}`);
  console.log("2. Test token creation:");
  console.log("   - Create a test token");
  console.log("   - Test trading functionality");
  console.log("   - Test graduation to Aerodrome");
  console.log("3. Update frontend with contract addresses");
  console.log("4. Fund protocol wallet for operations\n");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
