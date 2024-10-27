# Vuna Project

## Overview

The Vuna project is a decentralized application built on Ethereum, utilizing smart contracts to manage savings goals and automate deposits. It leverages the Aave protocol for lending and borrowing, and integrates with Gelato for task automation. The project is structured using Hardhat, a development environment for Ethereum software.

## Features

- **Savings Goals**: Users can set savings goals with specific target amounts and dates.
- **Automated Deposits**: Users can automate deposits towards their savings goals at specified intervals.
- **Yield Generation with ERC-4626**: The project uses the ERC-4626 standard to manage yield-bearing vaults, allowing users to earn yields on their deposited assets.
- **Integration with Aave**: The project uses Aave's lending pool to manage deposits and withdrawals.
- **Task Automation with Gelato**: Automates tasks such as periodic deposits using Gelato's infrastructure.


## Project Structure

- **Contracts**: Smart contracts are written in Solidity and include:
  - `Vuna.sol`: Main contract managing savings goals and deposits.
  - `VunaVault.sol`: Manages deposits into Aave's lending pool.
  - `MockGelato.sol`, `MockLendingPool.sol`, `MockAaveToken.sol`, `ERC20Mock.sol`: Mock contracts for testing purposes.

- **Tests**: Written in TypeScript using Chai for assertions and Hardhat for deployment and testing.
  - `Vuna.test.ts`: Tests for the Vuna contract.

- **Deployment**: Managed using Hardhat Ignition, with deployment scripts located in the `ignition/modules` directory.

## Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd vuna
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Compile contracts**:
   ```bash
   npx hardhat compile
   ```

4. **Run tests**:
   ```bash
   npx hardhat test
   ```

## Configuration

- **Environment Variables**: Use a `.env` file to store sensitive information such as private keys and API keys. Refer to the `.env.example` file for required variables.

- **Hardhat Configuration**: The `hardhat.config.ts` file contains network configurations and plugin settings.

## Usage

- **Deploy Contracts**: Use Hardhat Ignition to deploy contracts to a local or test network.
  ```bash
  npx hardhat ignition deploy ./ignition/modules/Vuna.ts --network baseSepolia
  ```

- **Interact with Contracts**: Use Hardhat tasks or scripts to interact with deployed contracts.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request for any improvements or bug fixes.

## License

This project is licensed under the MIT License.

## Acknowledgments

- [Hardhat](https://hardhat.org/)
- [Aave Protocol](https://aave.com/)
- [Gelato Network](https://www.gelato.network/)
- [OpenZeppelin](https://openzeppelin.com/)
