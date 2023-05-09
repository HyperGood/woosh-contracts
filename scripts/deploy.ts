import { ethers } from 'hardhat';

async function main() {
  const DepositVault = await ethers.getContractFactory('DepositVault');
  const depositVault = await DepositVault.deploy('DepositVault', '1.0.0');

  await depositVault.deployed();

  console.log(`Contract deployed to ${depositVault.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
