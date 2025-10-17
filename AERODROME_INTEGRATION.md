# 🚀 YUM.fun x Aerodrome Integration

## Overview

YUM.fun has successfully integrated with Aerodrome Finance's PoolLauncher and Locker system for seamless token graduation to Base's leading DEX.

## 📁 Project Structure

```
contracts/
├── YUMFactory.sol              # Main factory for token creation
├── YUMToken.sol                # Individual token contract with bonding curve
├── YUMAerodromeAdapter.sol     # Adapter for Aerodrome integration
├── AerodromeIntegration.sol    # Legacy placeholder (deprecated)
└── aerodrome/                  # Aerodrome Finance contracts
    ├── extensions/
    │   └── v2/
    │       ├── V2PoolLauncher.sol     # Pool launching logic
    │       ├── V2LockerFactory.sol    # Factory for lockers
    │       └── V2Locker.sol           # Individual locker contract
    ├── interfaces/              # Aerodrome interfaces
    ├── libraries/               # Helper libraries
    └── external/                # External contract interfaces
```

## 🔧 How It Works

### 1. **Token Creation** (Pre-Graduation)
- Users create YUM tokens via `YUMFactory`
- Each token has a bonding curve with:
  - Fixed supply: 1 billion tokens
  - Graduation threshold: 4 ETH
  - Virtual reserves: 30 ETH virtual, 1B tokens virtual

### 2. **Token Graduation** (When 4 ETH Raised)
When a token reaches the 4 ETH threshold:

```solidity
// YUMToken._graduate() is automatically called
// ├── Marks token as graduated
// ├── Transfers 20.7% tokens (207M) to adapter
// └── Calls YUMAerodromeAdapter.graduateToken()
      ├── Creates pool on Aerodrome via V2PoolLauncher
      ├── Adds liquidity (4 ETH + 207M tokens)
      └── Locks liquidity for 1 year via V2Locker
```

### 3. **Liquidity Locking**
- **Duration**: 365 days (configurable)
- **Amount**: 20.7% of total supply + all raised ETH
- **Owner**: Token creator
- **Bribeable**: 5% of rewards can be used for bribes

## 📦 Key Components

### YUMAerodromeAdapter

The adapter bridges YUM.fun with Aerodrome's infrastructure:

**Constructor Parameters:**
```solidity
constructor(
    address _poolLauncher,     // V2PoolLauncher address
    address _lockerFactory,    // V2LockerFactory address  
    address _pairedToken,      // WETH address on Base
    address _yumFactory,       // YUMFactory address
    address _owner             // Adapter owner
)
```

**Main Function:**
```solidity
function graduateToken(
    address yumToken,      // YUM token to graduate
    address creator,       // Token creator
    uint256 ethAmount,     // ETH for liquidity (4 ETH)
    uint256 tokenAmount    // Tokens for liquidity (207M)
) external payable returns (address pool, address locker)
```

### Aerodrome V2PoolLauncher

Creates pools and manages liquidity launch:

**Key Features:**
- Automatic pool creation if doesn't exist
- Liquidity provision with slippage protection
- Optional liquidity locking
- Refunds leftover tokens

### Aerodrome V2Locker

Locks liquidity with advanced features:

**Features:**
- Time-locked LP tokens
- Stakeable in gauges for rewards
- Fee collection from trading
- Bribeable rewards (5% configurable)
- Transferable ownership
- Increaseable liquidity & duration

## 🚀 Deployment

### Base Mainnet Addresses

```typescript
const AERODROME_V2_FACTORY = "0x420DD381b31aEf6683db6B902084cB0FFECe40Da";
const AERODROME_V2_ROUTER = "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43";
const WETH = "0x4200000000000000000000000000000000000006";
```

### Deployment Steps

```bash
# 1. Deploy YUMFactory
npx hardhat run scripts/deploy.ts --network base

# 2. Verify contracts on BaseScan
npx hardhat verify --network base <CONTRACT_ADDRESS>
```

### Deployment Script

The deployment script (`scripts/deploy.ts`) handles:
1. ✅ Deploy V2LockerFactory
2. ✅ Deploy V2PoolLauncher  
3. ✅ Deploy YUMFactory
4. ✅ Deploy YUMAerodromeAdapter
5. ✅ Configure pairable tokens (WETH)
6. ✅ Link all contracts together

## 🧪 Testing

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/YUMTest.ts

# Run with gas reporting
REPORT_GAS=true npx hardhat test
```

### Test Coverage

✅ Token creation (with/without first buy)  
✅ Trading functionality (buy/sell)  
✅ Fee collection and distribution  
✅ Graduation threshold tracking  
✅ Aerodrome adapter integration  
⏸️ Full graduation flow (requires live Aerodrome)

## 💡 Key Features

### Bonding Curve
- Uses constant product formula: `x * y = k`
- Dynamic pricing based on supply/demand
- No impermanent loss risk pre-graduation

### Fee Structure
| Action | Fee | Distribution |
|--------|-----|--------------|
| First Buy | 0.002 ETH | Protocol |
| Trading | 0.3% | 0.05% Protocol, 0.05% Creator, 0.20% LP |

### Graduation
| Parameter | Value | Notes |
|-----------|-------|-------|
| Threshold | 4 ETH | Net amount after fees |
| LP Tokens | 20.7% | 207M out of 1B |
| LP ETH | 4 ETH | All raised ETH |
| Lock Duration | 365 days | Configurable |

## 🔒 Security Considerations

### Access Control
- ✅ Factory owns token contracts
- ✅ Adapter only callable by factory
- ✅ Locker owned by token creator
- ✅ ReentrancyGuard on all external functions

### Slippage Protection
- ✅ 5% max slippage on pool creation
- ✅ Minimum amounts enforced (0.004 ETH first buy, 0.001 ETH trades)
- ✅ Refunds for excess tokens

### Error Handling
- ✅ Try-catch on graduation
- ✅ Revert on graduation failure
- ✅ Emergency withdraw function

## 📝 Important Notes

### Solidity Versions
- **YUM Contracts**: Solidity 0.8.20
- **Aerodrome Contracts**: Solidity 0.8.24 (requires Cancun EVM)

### EVM Version
The project uses **Cancun** EVM version for transient storage support in Aerodrome contracts.

### Paired Token
YUM tokens are paired with **WETH** on Base. The adapter handles token approvals automatically.

### Attribution
Aerodrome contracts (`contracts/aerodrome/`) are from [Aerodrome Finance](https://aerodrome.finance) and are licensed under BUSL-1.1.

## 🛠️ Configuration

### Hardhat Config
```typescript
solidity: {
  compilers: [
    {
      version: "0.8.24",
      settings: {
        optimizer: { enabled: true, runs: 200 },
        evmVersion: "cancun"  // Required for Aerodrome
      }
    },
    {
      version: "0.8.20",
      settings: {
        optimizer: { enabled: true, runs: 200 }
      }
    }
  ]
}
```

## 🚨 TODO for Production

- [ ] Deploy full Aerodrome infrastructure or use existing
- [ ] Add WETH wrapper for ETH conversion
- [ ] Implement graduation test with live contracts
- [ ] Add price oracle for better slippage protection
- [ ] Implement emergency pause mechanism
- [ ] Add multisig for owner operations
- [ ] Audit smart contracts
- [ ] Set up monitoring and alerts

## 📚 Resources

- **Aerodrome Finance**: https://aerodrome.finance
- **Base Network**: https://base.org
- **YUM.fun Docs**: (Coming soon)

## 🤝 Credits

- **Aerodrome Team**: For the excellent PoolLauncher & Locker system
- **Base Team**: For the amazing L2 infrastructure
- **OpenZeppelin**: For secure contract libraries

---

**Built with ❤️ for the Base ecosystem**


