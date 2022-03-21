async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0xd02a30d33153877bc20e5721ee53dedee0422b2f';
  const tokenName = 'g3CRV Curve Crypt';
  const tokenSymbol = 'rf-g3CRV';
  const depositFee = 0;
  const tvlCap = ethers.utils.parseEther('2000');
  const options = {gasPrice: 900000000000, gasLimit: 9000000};

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
