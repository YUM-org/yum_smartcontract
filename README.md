# YUM Smart Contract Project

This is a Hardhat project for developing and deploying smart contracts.

## Project Structure

```
yum_smartcontract/
├── contracts/          # Smart contracts
├── scripts/           # Deployment scripts
├── test/              # Test files
├── hardhat.config.js  # Hardhat configuration
└── package.json       # Project dependencies and scripts
```

## Getting Started

### Prerequisites

- Node.js (v16 or later)
- npm or yarn

### Installation

1. Install dependencies:
```bash
npm install
```

### Available Scripts

- `npm run compile` - Compile smart contracts
- `npm run test` - Run tests
- `npm run deploy` - Deploy contracts to local network
- `npm run deploy:localhost` - Deploy contracts to localhost network
- `npm run node` - Start local Hardhat network
- `npm run clean` - Clean build artifacts

### Usage

1. **Compile contracts:**
```bash
npm run compile
```

2. **Run tests:**
```bash
npm run test
```

3. **Start local network:**
```bash
npm run node
```

4. **Deploy contracts:**
```bash
npm run deploy
```

## Smart Contracts

### Lock Contract

The project includes a sample `Lock` contract that demonstrates:
- Time-locked withdrawals
- Owner-only functions
- Event emissions
- Ether transfers

## Development

- Add your smart contracts to the `contracts/` directory
- Write tests in the `test/` directory
- Create deployment scripts in the `scripts/` directory
- Configure networks in `hardhat.config.js`

## Testing

The project uses Hardhat's testing framework with Chai assertions. Run tests with:

```bash
npm test
```

## License

ISC
