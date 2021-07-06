from brownie import *
from config import (
    BADGER_DEV_MULTISIG,
    WANT,
    REWARD_TOKEN,
    PROTECTED_TOKENS,
    FEES
)
from dotmap import DotMap


def main():
    return deploy()


def deploy():
    """
      Deploys, vault, controller and strats and wires them up for you to test
    """
    deployer = accounts[0]

    strategist = deployer
    keeper = deployer
    guardian = deployer

    governance = accounts.at(BADGER_DEV_MULTISIG, force=True)

    controller = Controller.deploy({"from": deployer})
    controller.initialize(
        BADGER_DEV_MULTISIG,
        strategist,
        keeper,
        BADGER_DEV_MULTISIG
    )

    sett = SettV3.deploy({"from": deployer})
    sett.initialize(
        WANT,
        controller,
        BADGER_DEV_MULTISIG,
        keeper,
        guardian,
        False,
        "prefix",
        "PREFIX"
    )

    sett.unpause({"from": governance})
    controller.setVault(WANT, sett)

    # TODO: Add guest list once we find compatible, tested, contract
    # guestList = VipCappedGuestListWrapperUpgradeable.deploy({"from": deployer})
    # guestList.initialize(sett, {"from": deployer})
    # guestList.setGuests([deployer], [True])
    # guestList.setUserDepositCap(100000000)
    # sett.setGuestList(guestList, {"from": governance})

    #  Start up Strategy
    strategy = MyStrategy.deploy({"from": deployer})
    strategy.initialize(
        BADGER_DEV_MULTISIG,
        strategist,
        controller,
        keeper,
        guardian,
        PROTECTED_TOKENS,
        FEES
    )

    # Tool that verifies bytecode (run independetly) <- Webapp for anyone to verify

    # Set up tokens
    want = interface.IERC20(WANT)
    rewardToken = interface.IERC20(REWARD_TOKEN)

    #  Wire up Controller to Strart
    #  In testing will pass, but on live it will fail
    controller.approveStrategy(WANT, strategy, {"from": governance})
    controller.setStrategy(WANT, strategy, {"from": deployer})

    # Quickswap some tokens here
    router = Contract.from_explorer(
        "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff")

    WETH = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619"
    USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"

    weth = interface.IERC20(WETH)
    usdc = interface.IERC20(USDC)

    weth.approve("0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
                 999999999999999999999999999999, {"from": deployer})
    usdc.approve("0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
                 999999999999999999999999999999, {"from": deployer})

    #  MATIC -> WETH
    router.swapExactETHForTokens(
        0,
        ["0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
            WETH],
        deployer,
        9999999999999999,
        {"from": deployer, "value": 5000 * 10**18}
    )

    # MATIC -> USDC
    router.swapExactETHForTokens(
        0,
        ["0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", USDC],
        deployer,
        9999999999999999,
        {"from": deployer, "value": 5000 * 10**18}
    )

    # # Swap them from WETH-USDC
    router.addLiquidity(
        weth,
        usdc,
        weth.balanceOf(deployer),
        usdc.balanceOf(deployer),
        1,
        1,
        deployer,
        9999999999999999,
        {"from": deployer}
    )

    return DotMap(
        deployer=deployer,
        controller=controller,
        vault=sett,
        sett=sett,
        strategy=strategy,
        # guestList=guestList,
        want=want,
        rewardToken=rewardToken
    )
