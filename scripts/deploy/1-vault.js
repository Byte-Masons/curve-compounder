async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0x58e57cA18B7A47112b877E31929798Cd3D703b0f';
  const tokenName = 'Tricrypto Curve Crypt';
  const tokenSymbol = 'rf-crv3crypto';
  const depositFee = 0;
  const tvlCap = ethers.utils.parseEther('2000');
  const options = {gasPrice: 200000000000, gasLimit: 9000000};

  const vault = await Vault.deploy(wantAddress, tokenName, tokenSymbol, depositFee, tvlCap, options);

  await vault.deployed();
  console.log('Vault deployed to:', vault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
