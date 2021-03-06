const DeeCoinICO = artifacts.require('./DeeCoinICO.sol');

// various test utility functions
const transaction = (address, wei) => ({
  from: address,
  value: wei
});

const ethBalance = (address) => web3.eth.getBalance(address).toNumber();
const toWei = (number) => number * Math.pow(10, 18);
const fail = (msg) => (error) => assert(false, error ? `${msg}, but got error: ${error.message}` : msg);

const assertExpectedError = async (promise) => {
  try {
    await promise;
    fail('expected to fail')();
  } catch (error) {
    assert(error.message.indexOf('invalid opcode') >= 0, `Expected throw, but got: ${error.message}`);
  }
}

const timeController = (() => {

  const addSeconds = (seconds) => new Promise((resolve, reject) =>
    web3.currentProvider.sendAsync({
      jsonrpc: "2.0",
      method: "evm_increaseTime",
      params: [seconds],
      id: new Date().getTime()
    }, (error, result) => error ? reject(error) : resolve(result.result)));

  const addDays = (days) => addSeconds(days * 24 * 60 * 60);

  const currentTimestamp = () => web3.eth.getBlock(web3.eth.blockNumber).timestamp;

  return {
    addSeconds,
    addDays,
    currentTimestamp
  };
})();

contract('DeeCoinICO', accounts => {

  const fundsWallet = accounts[1];
  const buyerOneWallet = accounts[2];
  const buyerTwoWallet = accounts[3];
  const buyerThreeWallet = accounts[4];

  const oneEth = toWei(1);
  const minCap = toWei(14500);
  const maxCap = toWei(32700);

  const createToken = () => DeeCoinICO.new(fundsWallet, timeController.currentTimestamp());

  // REQ001: Basic ERC20 “Espeo Token” with symbol of “ESP”, 
  // 18 decimals (reflecting ether’s smallest unit - wei) 
  // and total supply of 1,000,000 units created at contract deployment 
  // and assigned to a specific wallet,
  it('should have initial supply of 30000000 units assigned to funds wallet', async () => {
    const deeCoinToken = await createToken();
    const expectedSupply = 60000000 * (10 ** 18);

    const totalSupply = await deeCoinToken.totalSupply();
    assert.equal(totalSupply, expectedSupply, 'Total supply mismatch');

    const fundsWalletBalance = await deeCoinToken.balanceOf(fundsWallet);
    assert.equal(fundsWalletBalance.toNumber(), expectedSupply, 'Initial funds wallet balance mismatch');
  });

  
  it('test transfer', async () => {
    const deeCoinToken = await createToken();
    await deeCoinToken.sendTransaction(transaction(buyerOneWallet, toWei(0.3)));

    assert.equal(ethBalance(deeCoinToken.address), toWei(0.3), 'Contract balance mismatch');


    await assertExpectedError(deeCoinToken.sendTransaction(transaction(buyerTwoWallet, toWei(0.001))));
    assert.equal(ethBalance(deeCoinToken.address), toWei(0.3), 'Contract balance mismatch');

    await deeCoinToken.sendTransaction(transaction(buyerTwoWallet, toWei(1)));
    assert.equal(ethBalance(deeCoinToken.address), toWei(1.3), 'Contract balance mismatch');
  });

  it('should close after the max cap', async () => {
    const deeCoinToken = await createToken();

    await deeCoinToken.sendTransaction(transaction(buyerOneWallet, oneEth));
    // should allow going over max cap
    await deeCoinToken.sendTransaction(transaction(buyerTwoWallet, maxCap));

    // should close after reaching max cap
    await assertExpectedError(deeCoinToken.sendTransaction(transaction(buyerThreeWallet, oneEth)));

    const totalRaised = await deeCoinToken.totalRaised();
    assert.equal(totalRaised.toNumber(), toWei(32700+1), 'Total raised amount mismatch'+totalRaised);
  });


  it('admin withdraw after close', async () => {
    const deeCoinToken = await createToken();

    await deeCoinToken.sendTransaction(transaction(buyerOneWallet, oneEth));
    await deeCoinToken.sendTransaction(transaction(buyerTwoWallet, maxCap));

    const totalRaised = await deeCoinToken.totalRaised();
    const currentBalance = ethBalance(fundsWallet);
    
    await deeCoinToken.adminWithdrawDevETH({from: fundsWallet});

    const newBalance = ethBalance(fundsWallet);

    assert.equal((oneEth+maxCap)*0.7/(toWei(1)), (newBalance-currentBalance)/toWei(1) , 'Total raised amount mismatch');
  });

});

