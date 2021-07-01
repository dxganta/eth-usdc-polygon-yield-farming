# Ideally, they have one file with the settings for the strat and deployment
# This file would allow them to configure so they can test, deploy and interact with the strategy

BADGER_DEV_MULTISIG = "0xb65cef03b9b89f99517643226d76e286ee999e77"

WANT = "0x853Ee4b2A13f8a742d64C8F088bE7bA2131f670d"  # WETH-USDC
REWARD_TOKEN = "0x831753dd7087cac61ab5644b308642cc1c33dc13"  # QUICK

PROTECTED_TOKENS = [WANT, REWARD_TOKEN]
#  Fees in Basis Points
DEFAULT_GOV_PERFORMANCE_FEE = 1000
DEFAULT_PERFORMANCE_FEE = 1000
DEFAULT_WITHDRAWAL_FEE = 75

FEES = [DEFAULT_GOV_PERFORMANCE_FEE,
        DEFAULT_PERFORMANCE_FEE, DEFAULT_WITHDRAWAL_FEE]
