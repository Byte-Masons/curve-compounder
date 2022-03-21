async function main() {
  const vaultAddress = '0xB61D0e1F5538c7566907F3Edc87440B43d81d641';
  const strategyAddress = '0x0b2Bab383D378576bd4E64b6d3AcCFfBD81061A3';
  const options = {gasPrice: 300000000000, gasLimit: 9000000};

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);

  await vault.initialize(strategyAddress, options);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
