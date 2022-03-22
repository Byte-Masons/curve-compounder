async function main() {
  const vaultAddress = '0x66f9207360067a537eA1a4a8f4474E4d8359a038';
  const strategyAddress = '0xBE320C7C61F2131880df4eD41D6Adc65050c8A19';
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
