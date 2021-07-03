# Quickswap WETH-USDC Liquidity Pool Yield Farming (Polygon Mainnet)

This mix is configured for use with [Ganache](https://github.com/trufflesuite/ganache-cli) on a [forked mainnet](https://eth-brownie.readthedocs.io/en/stable/network-management.html#using-a-forked-development-network).

## How it Works
### Deposit
The Strategy takes Quickswap's Quick-v2 WETH-USDC Liquidity Pool tokens as deposit and stakes them for yield generation. You can get Quick-v2 WETH-USDC tokens [here](https://quickswap.exchange/#/add/0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619/0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174).
### Harvest & Compounding
Including the APY from providing liquidity in the WETH-USDC pool, the user also gets QUICK rewards for staking the WETH-USDC LP tokens.

The strategy converts the QUICK tokens to 50% WETH & 50% USDC. Then it adds them to the WETH-USDC Liquidity Pool on Quickswap for WETH-USDC LP Tokens. 

These WETH-USDC LP Tokens are then reinvested back into the strategy further yield generation.
### Withdrawing Funds
On withdraw call, the strategy simply unstakes the WETH-USDC tokens and returns them back to the user based on the number of vault shares that the user owns.

## Expected Yield

As of July 3, 2021

Rewards -> (80 Quick Per day) 13.18% APY <br>
Fees -> 14.76% APY

Total -> <strong>27.94%</strong>

Note: One very notable point about this pool is the high fees APY which means that there is high volume going through the pool everyday. This is a very big pool with 111 M dollars TVL. Just few days ago the Fees APY was at 30%. With increasing deposits in the pool, though the rewards APY will decrease, the user can still enjoy high Fees APY which will only keep increasing with increasing Volume in this Pool.

## Usage

### For Users (Callable by anyone)
A user just has to call the <strong>deposit()</strong> function in the Vault Contract to deposit his DAI. The Vault will provide him the required number of Vault Shares.

To withdraw his funds, the user just has to call the <strong>withdraw()</strong> function with the number of Vault shares he wants to liquidate and the Vault will return his deserved DAI as per the Vault shares.

(Ofcourse the user won't call the functions directly, but through a frontend component which will implement the above 2 functions through 2 buttons namely <strong>DEPOSIT</strong> & <strong>WITHDRAW</strong>)

### For Force Team (Below functions can only be called by authorized accounts)
The Force Team has to call the <strong>earn()</strong> function in the Vault Contract to deposit the DAI from the Vault Contract into the Strategy to start yield generation.

There is a <strong>harvest()</strong> function in the Strategy Contract which has to be called periodically by the Force Team (generally every month or week) to realize the WMATIC/CRV rewards & convert it to DAI.

After the harvest() you may call the <strong>tend()</strong> function which will deposit any idle DAI held by the strategy contract back into the pools for yield generation.

(Ofcourse all the conversions & deposits are automated inside the strategy, you just have to call the above 3 functions)

## Documentation
A general template for the Strategy, Controller, Vault has generated from https://github.com/GalloDaSballo/badger-strategy-mix-v1

### The Vault Contract ([/contracts/deps/SettV3.sol](https://github.com/realdiganta/dbr-aave-polygon-strategy/blob/main/contracts/deps/SettV3.sol)) has 3 prime functions

<strong>deposit(uint256 _amount)</strong>
```
params: (_amount) => Amount of DAI

info: Deposits DAI into the Vault Contract & returns corresponding shares to the user
access: public
```

<strong>withdraw(uint256 _shares)</strong>
```
params: (_shares) => Number of Vault Shares held by user

info: Takes the shares from the user, burns them & returns corresponding DAI to the user
access: public
```

<strong>earn()</strong>
```
info: Deposits the DAI held by the Vault Contract to the controller. The Controller will then deposit into the Strategy for yield-generation.

access: Only Authorized Actors
```
<br>

### The Controller Contract ([/contracts/deps/Controller.sol](https://github.com/realdiganta/dbr-aave-polygon-strategy/blob/main/contracts/deps/Controller.sol))
The prime function of the Controller is to set, approve & remove Strategies for the Vault and act as a middleman between the Vault & the strategy(ies).
<br><br>
### The Strategy Contract ([/contracts/MyStrategy.sol](https://github.com/realdiganta/dbr-aave-polygon-strategy/blob/main/contracts/MyStrategy.sol)) :
 
<strong>deposit()</strong>
```
info: Deposits all DAI held by the strategy into the AAVE & Curve Pools (converting them into USDC & USDT as required) for yield generation.

access: Only Authorized Actors & Controller Contract.
```

<strong> harvest()</strong>
```
info: realizes Matic & Curve rewards and converts them to DAI.

access: Only Authorized Actors
```

<strong>tend()</strong>
```
info: reinvests the DAI held by the strategy back into the pools. Generally to be called after the harvest() function.

access: Only Authorized Actors
```

<strong>withdraw(uint256 _amount)</strong>
```
params: (_amount) => _amount in DAI to withdraw

info: withdraws funds from the strategy, unrolling from strategy positions as necessary
access: Only Controller
```

<strong>withdrawAll()</strong>
```
info: withdraws all the funds from the strategy.

access: Only Controller
```

<strong>changeAllocations(uint16[4] _allocations)</strong>
```
params: (_allocations) => list of allocations for the different pools. (where 100 will be 10%) with order being [dai, usdc, usdt, curve]

info: The values in the list must add up to 1000. This function may typically be called by the strategist when the APYs in the various pools changes to have a better allocation of the funds of the strategy for higher net APY.

access: Only Authorized Actors
```

## Installation and Setup

Install the dependencies in the package
```
## Javascript dependencies
npm i

## Python Dependencies
pip install virtualenv
virtualenv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Basic Use

To deploy the Strategy in a development environment:

1. Compile the contracts 
```
  brownie compile
```

2. Run Scripts for Deployment
```
  brownie run deploy
```
Deployment will set up a Vault, Controller and deploy your strategy

3. Testing. To run all the tests in the tests folder 
``` 
brownie test
```

4. Run the test deployment in the console and interact with it
```python
  brownie console
  deployed = run("deploy")

  ## Takes a minute or so
  Transaction sent: 0xa0009814d5bcd05130ad0a07a894a1add8aa3967658296303ea1f8eceac374a9
  Gas price: 0.0 gwei   Gas limit: 12000000   Nonce: 9
  UniswapV2Router02.swapExactETHForTokens confirmed - Block: 12614073   Gas used: 88626 (0.74%)

  ## Now you can interact with the contracts via the console
  >>> deployed
  {
      'controller': 0x602C71e4DAC47a042Ee7f46E0aee17F94A3bA0B6,
      'deployer': 0x66aB6D9362d4F35596279692F0251Db635165871,
      'rewardToken': 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
      'sett': 0x6951b5Bd815043E3F842c1b026b0Fa888Cc2DD85,
      'strategy': 0x9E4c14403d7d9A8A782044E86a93CAE09D7B2ac9,
      'vault': 0x6951b5Bd815043E3F842c1b026b0Fa888Cc2DD85,
      'want': 0x6B175474E89094C44Da98b954EedeAC495271d0F
  }
  >>>

  ## Deploy also uniswaps want to the deployer (accounts[0]), so you have funds to play with!
  >>> deployed.want.balanceOf(a[0])
  240545908911436022026

```
## Deployment

You can have a look at the deployment script at (/scripts/deploy.py)

When you are finished testing and ready to deploy to the mainnet:

1. [Import a keystore](https://eth-brownie.readthedocs.io/en/stable/account-management.html#importing-from-a-private-key) into Brownie for the account you wish to deploy from.
2. Run [`scripts/deploy.py`](scripts/deploy.py) with the following command

```bash
$ brownie run deployment --network mainnet
```

You will be prompted to enter your keystore password, and then the contract will be deployed.
