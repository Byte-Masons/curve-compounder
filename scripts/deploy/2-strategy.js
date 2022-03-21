const hre = require('hardhat');

async function main() {
  const vaultAddress = '0xB61D0e1F5538c7566907F3Edc87440B43d81d641';
  const Strategy = await ethers.getContractFactory('ReaperStrategyCurve');
  const treasuryAddress = '0x0e7c5313E9BB80b654734d9b7aB1FB01468deE3b';
  const paymentSplitterAddress = '0x63cbd4134c2253041F370472c130e92daE4Ff174';
  const strategist1 = '0x1E71AEE6081f62053123140aacC7a06021D77348';
  const strategist2 = '0x81876677843D00a7D792E1617459aC2E93202576';
  const strategist3 = '0x1A20D7A31e5B3Bc5f02c8A146EF6f394502a10c4';
  const curvePool = '0x0fa949783947bf6c1b171db13aeacbb488845b3f';
  const gauge = '0xd4f94d0aaa640bbb72b5eec2d85f6d114d81a88e';
  const depositIndex = 1;
  const wftmToDepositPath = [
    '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
    '0x04068DA6C83AFCFA0e13ba15A6696662335D5B75',
  ];

  const strategy = await hre.upgrades.deployProxy(
    Strategy,
    [
      vaultAddress,
      [treasuryAddress, paymentSplitterAddress],
      [strategist1, strategist2, strategist3],
      curvePool,
      gauge,
      depositIndex,
      wftmToDepositPath,
    ],
    {kind: 'uups', timeout: 0, gasPrice: 300000000000, gasLimit: 9000000},
  );

  await strategy.deployed();
  console.log('Strategy deployed to:', strategy.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
