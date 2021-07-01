// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../interfaces/badger/IController.sol";
import "../interfaces/uniswap/IStakingRewards.sol";
import "../interfaces/uniswap/IUniswapRouterV2.sol";


import {
    BaseStrategy
} from "../deps/BaseStrategy.sol";

contract MyStrategy is BaseStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow
    // we provide liquidity with want
    address public reward; // Token we farm and swap to want (QUICK)

    address public constant STAKING_REWARDS = 0x4A73218eF2e820987c59F838906A82455F42D98b;
    address public constant QUICKSWAP_ROUTER = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;

    address public constant usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    // slippage tolerance 0.5% (divide by 1000) 
    uint256 public sl = 5;

    function initialize(
        address _governance,
        address _strategist,
        address _controller,
        address _keeper,
        address _guardian,
        address[2] memory _wantConfig,
        uint256[3] memory _feeConfig
    ) public initializer {
        __BaseStrategy_init(_governance, _strategist, _controller, _keeper, _guardian);

        /// @dev Add config here
        want = _wantConfig[0];
        reward = _wantConfig[1];

        performanceFeeGovernance = _feeConfig[0];
        performanceFeeStrategist = _feeConfig[1];
        withdrawalFee = _feeConfig[2];

        /// @dev do one off approvals here
        IERC20Upgradeable(want).safeApprove(STAKING_REWARDS, type(uint256).max);
        IERC20Upgradeable(weth).safeApprove(STAKING_REWARDS, type(uint256).max);
        IERC20Upgradeable(usdc).safeApprove(STAKING_REWARDS, type(uint256).max);

        IERC20Upgradeable(reward).safeApprove(QUICKSWAP_ROUTER, type(uint256).max);
        IERC20Upgradeable(weth).safeApprove(QUICKSWAP_ROUTER, type(uint256).max);
        IERC20Upgradeable(usdc).safeApprove(QUICKSWAP_ROUTER, type(uint256).max);

    }

    /// ===== View Functions =====

    // @dev Specify the name of the strategy
    function getName() external override pure returns (string memory) {
        return "QUICKSWAP ETH-USDC Farming";
    }

    // @dev Specify the version of the Strategy, for upgrades
    function version() external pure returns (string memory) {
        return "1.0";
    }

    /// @dev Balance of want currently held in strategy positions
    function balanceOfPool() public override view returns (uint256) {
        return IStakingRewards(STAKING_REWARDS).balanceOf(address(this))
        .add(balanceOfToken(usdc))
        .add(balanceOfToken(weth));
    }

    function balanceOfToken(address _token) public view returns (uint256) {
        return IERC20Upgradeable(_token).balanceOf(address(this));
    }
    
    /// @dev Returns true if this strategy requires tending
    function isTendable() public override view returns (bool) {
        return true;
    }

    // @dev These are the tokens that cannot be moved except by the vault
    function getProtectedTokens() public override view returns (address[] memory) {
        address[] memory protectedTokens = new address[](2);
        protectedTokens[0] = want;
        protectedTokens[1] = reward;
        return protectedTokens;
    }

    /// ===== Permissioned Actions: Governance =====
    /// @notice Delete if you don't need!
    function setKeepReward(uint256 _setKeepReward) external {
        _onlyGovernance();
    }

    /// ===== Internal Core Implementations =====

    /// @dev security check to avoid moving tokens that would cause a rugpull, edit based on strat
    function _onlyNotProtectedTokens(address _asset) internal override {
        address[] memory protectedTokens = getProtectedTokens();

        for(uint256 x = 0; x < protectedTokens.length; x++){
            require(address(protectedTokens[x]) != _asset, "Asset is protected");
        }
    }


    /// @dev invest the amount of want
    /// @notice When this function is called, the controller has already sent want to this
    /// @notice Just get the current balance and then invest accordingly
    /// @notice stake the want tokens in the LP pool
    function _deposit(uint256 _amount) internal override {
        IStakingRewards(STAKING_REWARDS).stake(_amount);
    }

    /// @dev utility function to withdraw everything for migration
    function _withdrawAll() internal override {
        uint256 _totalWant = IStakingRewards(STAKING_REWARDS).balanceOf(address(this));
        if (_totalWant > 0) {
        _withdrawSome(_totalWant);
        }
    }
    /// @dev withdraw the specified amount of want, liquidate from lpComponent to want, paying off any necessary debt for the conversion
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        uint256 _totalWant = IStakingRewards(STAKING_REWARDS).balanceOf(address(this));
        if (_amount > _totalWant) {
            _amount = _totalWant;
        }
        IStakingRewards(STAKING_REWARDS).withdraw(_amount);
        return _amount;
    }

    /// @notice check unclaimed quick rewards
    function checkPendingReward() public view returns (uint256) {
        return IStakingRewards(STAKING_REWARDS).earned(address(this));
    }

    function testDeposit(uint256 _amount) external {
        _deposit(_amount);
    }

    function testWithdraw() external {
        _withdrawAll();
    }

    function testRewards() external {
        IStakingRewards(STAKING_REWARDS).getReward();
    }

    /// @dev Harvest from strategy mechanics, realizing increase in underlying position
    function harvest() external whenNotPaused returns (uint256 harvested) {
        _onlyAuthorizedActors();

        uint256 _before = IERC20Upgradeable(want).balanceOf(address(this));

        uint256 _reward = checkPendingReward();

        if (_reward == 0) {
            return 0;
        }

        // take out reward quick tokens
        IStakingRewards(STAKING_REWARDS).getReward();

        // exchange quick tokens for WETH-USDC tokens 
         _quickToLP();

        uint256 earned = IERC20Upgradeable(want).balanceOf(address(this)).sub(_before);

        /// @notice Keep this in so you get paid!
        (uint256 governancePerformanceFee, uint256 strategistPerformanceFee) = _processPerformanceFees(earned);

        /// @dev Harvest event that every strategy MUST have, see BaseStrategy
        emit Harvest(earned, block.number);

        return earned;
    }

    // Alternative Harvest with Price received from harvester, used to avoid exessive front-running
    function harvest(uint256 price) external whenNotPaused returns (uint256 harvested) {

    }

    /// @dev Rebalance, Compound or Pay off debt here
    function tend() external whenNotPaused {
        _onlyAuthorizedActors();
        // restake want into the rewards contract
        uint256 _want = balanceOfWant();
        if (_want > 0) {
            _deposit(_want);
        }
    }


    /// ===== Internal Helper Functions =====
    
    /// @dev used to manage the governance and strategist fee, make sure to use it to get paid!
    function _processPerformanceFees(uint256 _amount) internal returns (uint256 governancePerformanceFee, uint256 strategistPerformanceFee) {
        governancePerformanceFee = _processFee(want, _amount, performanceFeeGovernance, IController(controller).rewards());

        strategistPerformanceFee = _processFee(want, _amount, performanceFeeStrategist, strategist);
    }

    /// @dev QUICK TO WETH-USDC LP 
    function _quickToLP() internal {
        uint256 _tokens = balanceOfToken(reward);
        uint256 _half = _tokens.mul(500).div(1000);

        // quick to weth
        address[] memory path = new address[](2);
        path[0] = reward;
        path[1] = weth;
        IUniswapRouterV2(QUICKSWAP_ROUTER).swapExactTokensForTokens(_half, 0, path, address(this), now);

        // quick to usdc
        path = new address[](2);
        path[0] = reward;
        path[1] = usdc;
        IUniswapRouterV2(QUICKSWAP_ROUTER).swapExactTokensForTokens(_tokens.sub(_half), 0, path, address(this), now);

        uint256 _wethIn = balanceOfToken(weth);
        uint256 _usdcIn = balanceOfToken(usdc);
        // add to WETH-USDC LP pool for pool tokens
        IUniswapRouterV2(QUICKSWAP_ROUTER).addLiquidity(weth, usdc, _wethIn, _usdcIn, _wethIn.mul(sl).div(1000), _usdcIn.mul(sl).div(1000), address(this), now);
    }   

    function setSlippageTolerance(uint256 _s) external {
        _onlyGovernanceOrStrategist();
        sl = _s;
    }
}
