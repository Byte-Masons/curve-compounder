// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./abstract/ReaperBaseStrategyv1_1.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/ICurveRegistry.sol";
import "./interfaces/ICurveSwap.sol";
import "./interfaces/ICurveSwap3.sol";
import "./interfaces/IRewardsGauge.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @dev Deposit a Curve LP token into the Curve rewardGauge to farm WFTM, CRV, GEIST
 */
contract ReaperStrategyCurve is ReaperBaseStrategyv1_1 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // 3rd-party contract addresses
    address public constant SPOOKY_ROUTER = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    address public constant CURVE_REGISTRY = address(0x0f854EA9F38ceA4B1c2FC79047E9D0134419D5d6);
    address public swapPool;
    address public rewardsGauge;

    /**
     * @dev Tokens Used:
     * {WFTM} - Required for liquidity routing when doing swaps. Also reward token.
     * {CRV} - Reward token.
     * {GEIST} - Reward token.
     * {want} - The Curve LP token (like tricrypto)
     * {depositToken} - Token that is part of the want LP and can be used to deposit and create the LP
     */
    address public constant WFTM = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public constant CRV = address(0x1E4F97b9f9F913c46F1632781732927B9019C68b);
    address public constant GEIST = address(0xd8321AA83Fb0a4ECd6348D4577431310A6E0814d);
    address public want;
    address public depositToken;

    /**
     * @dev Paths used to swap tokens:
     * {crvToWftmPath} - to swap {CRV} to {WFTM} (using SPOOKY_ROUTER)
     * {geistToWftmPath} - to swap {GEIST} to {WFTM} (using SPOOKY_ROUTER)
     * {wftmToDepositPath} - to swap {WFTM} to {depositToken} (using SPOOKY_ROUTER)
     */
    address[] public crvToWftmPath;
    address[] public geistToWftmPath;
    address[] public wftmToDepositPath;

    /**
     * @dev Curve variables
     * {depositIndex} - The index of the token in the want LP used to deposit and create the LP
     */
    uint256 public depositIndex;

    /**
     * @dev Initializes the strategy. Sets parameters and saves routes.
     * @notice see documentation for each variable above its respective declaration.
     */
    function initialize(
        address _vault,
        address[] memory _feeRemitters,
        address[] memory _strategists,
        address _pool,
        address _gauge,
        uint256 _depositIndex,
        address[] memory _wftmToDepositPath
    ) public initializer {
        __ReaperBaseStrategy_init(_vault, _feeRemitters, _strategists);
        swapPool = _pool;
        rewardsGauge = _gauge;
        want = ICurveRegistry(CURVE_REGISTRY).get_lp_token(swapPool);
        setDepositTokenParams(_depositIndex, _wftmToDepositPath);
        crvToWftmPath = [CRV, WFTM];
        geistToWftmPath = [GEIST, WFTM];
        _giveAllowances();
    }

    /**
     * @dev Function that puts the funds to work.
     *      It gets called whenever someone deposits in the strategy's vault contract.
     */
    function _deposit() internal override {
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBalance != 0) {
            IRewardsGauge(rewardsGauge).deposit(wantBalance, address(this), false);
        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */
    function _withdraw(uint256 _amount) internal override {
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        if (wantBalance < _amount) {
            IRewardsGauge(rewardsGauge).withdraw(_amount - wantBalance, false);
        }

        IERC20Upgradeable(want).safeTransfer(vault, _amount);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     *      1. Claims rewards
     *      2. Swaps reward tokens to wftm
     *      3. Claims fees for the harvest caller and treasury
     *      4. Creates the want LP tokens
     *      5. Deposits new LP tokens
     */
    function _harvestCore() internal override {
        _claimRewards();
        _swapRewards();
        _chargeFees();
        _addLiquidity();
        _deposit();
    }

    /**
     * @dev Core harvest function. Claims {WFTM}, {GEIST} and {CRV} rewards from the gauge.
     */
    function _claimRewards() internal {
        IRewardsGauge(rewardsGauge).claim_rewards();
    }

    /**
     * @dev Core harvest function. Swaps {GEIST} and {CRV} balances into {WFTM}.
     */
    function _swapRewards() internal {
        uint256 crvBal = IERC20Upgradeable(CRV).balanceOf(address(this));
        uint256 geistBal = IERC20Upgradeable(GEIST).balanceOf(address(this));
        _swap(crvBal, crvToWftmPath);
        _swap(geistBal, geistToWftmPath);
    }

    /**
     * @dev Helper function to swap tokens given an {_amount} and {_path},
     */
    function _swap(uint256 _amount, address[] memory _path) internal {
        if (_path.length < 2 || _amount == 0) {
            return;
        }

        IUniswapV2Router02(SPOOKY_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            _path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Core harvest function.
     *      Charges fees based on the amount of WFTM gained from reward
     */
    function _chargeFees() internal {
        IERC20Upgradeable wftm = IERC20Upgradeable(WFTM);
        uint256 wftmFee = (wftm.balanceOf(address(this)) * totalFee) / PERCENT_DIVISOR;
        if (wftmFee != 0) {
            uint256 callFeeToUser = (wftmFee * callFee) / PERCENT_DIVISOR;
            uint256 treasuryFeeToVault = (wftmFee * treasuryFee) / PERCENT_DIVISOR;
            uint256 feeToStrategist = (treasuryFeeToVault * strategistFee) / PERCENT_DIVISOR;
            treasuryFeeToVault -= feeToStrategist;

            wftm.safeTransfer(msg.sender, callFeeToUser);
            wftm.safeTransfer(treasury, treasuryFeeToVault);
            wftm.safeTransfer(strategistRemitter, feeToStrategist);
        }
    }

    /**
     * @dev Core harvest function. Adds more liquidity using {depositToken}
     */
    function _addLiquidity() internal {
        uint256 wftmBal = IERC20Upgradeable(WFTM).balanceOf(address(this));
        _swap(wftmBal, wftmToDepositPath);

        uint256 depositBalance = IERC20Upgradeable(depositToken).balanceOf(address(this));

        if (depositBalance != 0) {
            uint256[3] memory amounts;
            amounts[depositIndex] = depositBalance;
            ICurveSwap3(swapPool).add_liquidity(amounts, 0, true);
        }
    }

    /**
     * @dev Function to calculate the total {want} held by the strat.
     *      It takes into account both the funds in hand, plus the funds in the MasterChef.
     */
    function balanceOf() public view override returns (uint256) {
        return balanceOfWant() + balanceOfPool();
    }

    // it calculates how much 'want' this contract holds.
    // could probably inline this it's only used in one spot
    function balanceOfWant() public view returns (uint256) {
        return IERC20Upgradeable(want).balanceOf(address(this));
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view returns (uint256) {
        return IRewardsGauge(rewardsGauge).balanceOf(address(this));
    }

    /**
     * @dev Returns the approx amount of profit from harvesting.
     *      Profit is denominated in WFTM, and takes fees into account.
     */
    function estimateHarvest() external view override returns (uint256 profit, uint256 callFeeToUser) {
        uint256 pendingCRVReward = IRewardsGauge(rewardsGauge).claimable_reward(address(this), CRV);
        uint256 totalCRVRewards = pendingCRVReward + IERC20Upgradeable(CRV).balanceOf(address(this));
        uint256 pendingGeistReward = IRewardsGauge(rewardsGauge).claimable_reward(address(this), GEIST);
        uint256 totalGeistRewards = pendingGeistReward + IERC20Upgradeable(GEIST).balanceOf(address(this));
        uint256 pendingWFTMReward = IRewardsGauge(rewardsGauge).claimable_reward(address(this), WFTM);
        uint256 totalWFTMRewards = pendingWFTMReward + IERC20Upgradeable(WFTM).balanceOf(address(this));

        if (totalCRVRewards != 0) {
            profit += IUniswapV2Router02(SPOOKY_ROUTER).getAmountsOut(totalCRVRewards, crvToWftmPath)[1];
        }
        if (totalGeistRewards != 0) {
            profit += IUniswapV2Router02(SPOOKY_ROUTER).getAmountsOut(totalGeistRewards, geistToWftmPath)[1];
        }

        profit += totalWFTMRewards;

        uint256 wftmFee = (profit * totalFee) / PERCENT_DIVISOR;
        callFeeToUser = (wftmFee * callFee) / PERCENT_DIVISOR;
        profit -= wftmFee;
    }

    /**
     * @notice Admin function to update depositToken-related variables. Public instead of internal
     *         since we also call this during initialization.
     */
    function setDepositTokenParams(uint256 _newDepositIndex, address[] memory _newDepositToWftmPath) public {
        _onlyStrategistOrOwner();

        uint256 numTokens = ICurveRegistry(CURVE_REGISTRY).get_n_coins(swapPool)[0];
        require(_newDepositIndex < numTokens, "out of bounds!");
        depositIndex = _newDepositIndex;
        depositToken = ICurveSwap(swapPool).underlying_coins(_newDepositIndex);
        wftmToDepositPath = _newDepositToWftmPath;

        uint256 depositTokenAllowance = type(uint256).max -
            IERC20Upgradeable(depositToken).allowance(address(this), swapPool);
        IERC20Upgradeable(depositToken).safeIncreaseAllowance(swapPool, depositTokenAllowance);
    }

    /**
     * @dev Function to retire the strategy. Claims all rewards and withdraws
     *      all principal from external contracts, and sends everything back to
     *      the vault. Can only be called by strategist or owner.
     *
     * Note: this is not an emergency withdraw function. For that, see panic().
     */
    function _retireStrat() internal override {
        _harvestCore();
        IRewardsGauge(rewardsGauge).withdraw(balanceOfPool());
        uint256 wantBalance = IERC20Upgradeable(want).balanceOf(address(this));
        IERC20Upgradeable(want).transfer(vault, wantBalance);
    }

    /**
     * Withdraws all funds leaving rewards behind.
     */
    function _reclaimWant() internal override {
        bool claimRewards = false;
        IRewardsGauge(rewardsGauge).withdraw(balanceOfPool(), claimRewards);
    }

    /**
     * @dev Gives all the necessary allowances to:
     *      - deposit {want} into {rewardsGauge}
     *      - swap {CRV} using {SPOOKY_ROUTER}
     *      - swap {GEIST} using {SPOOKY_ROUTER}
     *      - swap {WFTM} using {SPOOKY_ROUTER}
     */
    function _giveAllowances() internal override {
        // want -> rewardsGauge
        uint256 wantAllowance = type(uint256).max - IERC20Upgradeable(want).allowance(address(this), rewardsGauge);
        IERC20Upgradeable(want).safeIncreaseAllowance(rewardsGauge, wantAllowance);
        // CRV -> SPOOKY_ROUTER
        uint256 crvAllowance = type(uint256).max - IERC20Upgradeable(CRV).allowance(address(this), SPOOKY_ROUTER);
        IERC20Upgradeable(CRV).safeIncreaseAllowance(SPOOKY_ROUTER, crvAllowance);
        // GEIST -> SPOOKY_ROUTER
        uint256 geistAllowance = type(uint256).max - IERC20Upgradeable(GEIST).allowance(address(this), SPOOKY_ROUTER);
        IERC20Upgradeable(GEIST).safeIncreaseAllowance(SPOOKY_ROUTER, geistAllowance);
        // WFTM -> SPOOKY_ROUTER
        uint256 wftmAllowance = type(uint256).max - IERC20Upgradeable(WFTM).allowance(address(this), SPOOKY_ROUTER);
        IERC20Upgradeable(WFTM).safeIncreaseAllowance(SPOOKY_ROUTER, wftmAllowance);
    }

    /**
     * @dev Removes all the allowances that were given above.
     */
    function _removeAllowances() internal override {
        IERC20Upgradeable(want).safeDecreaseAllowance(
            rewardsGauge,
            IERC20Upgradeable(want).allowance(address(this), rewardsGauge)
        );
        IERC20Upgradeable(CRV).safeDecreaseAllowance(
            SPOOKY_ROUTER,
            IERC20Upgradeable(CRV).allowance(address(this), SPOOKY_ROUTER)
        );
        IERC20Upgradeable(GEIST).safeDecreaseAllowance(
            SPOOKY_ROUTER,
            IERC20Upgradeable(GEIST).allowance(address(this), SPOOKY_ROUTER)
        );
        IERC20Upgradeable(WFTM).safeDecreaseAllowance(
            SPOOKY_ROUTER,
            IERC20Upgradeable(WFTM).allowance(address(this), SPOOKY_ROUTER)
        );
        IERC20Upgradeable(depositToken).safeDecreaseAllowance(
            swapPool,
            IERC20Upgradeable(depositToken).allowance(address(this), swapPool)
        );
    }
}
