// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IPool.sol";
import "./interfaces/IStrategy.sol";

/// @title  Pool
/// @notice Liquidity pool for for depositing tokens. For every token deposited
///         into the pool, a LP token token is minted, representing a share of the pool.
///         LP tokens can be redeemed for the underlying tokens.
/// @dev    needs to be upgradeable, so that it complies with the beacon proxy pattern.
contract Pool is ERC20Upgradeable, IPool, OwnableUpgradeable {

    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    uint256 public constant DEFAULT_LPT_RATE = 1000;
    uint256 private constant FULL_ALLOC = 100000000;
    uint256 private constant MARGIN_ALLOC = 1000000; // 1%

    /// @notice when LP amount was redeemed
    event Redeemed(address indexed beneficiary, uint256 amount);

    /// @notice when LP amount was minted as a result of a deposit
    event Deposited(address indexed beneficiary, uint256 amount);

    /// @notice underlying token of the pool
    ERC20 public underlying;

    /// @notice underlying token decimal
    uint256 public underlyingUnit;

    //  @notice Strategy address
    address public override underlyingStrategy;

    // Current fee on interest gained
    uint256 public fee;

    // fee contract address
    address public feeAddress;

    // Map that saves avg price paid for each user, used to calculate earnings
    mapping(address => uint256) public userAvgPrices;

    /// @notice Initialize the contract instead of a constructor during deployment.
    /// @param  _name name of the LP token
    /// @param  _symbol symbol of the LP token
    /// @param  _token underlying token address
    /// @param  _owner contract owner
    function initialize(
        string memory _name, string memory _symbol, address _token,
        address _feeAddress, uint256 _fee, address _strategy, address _owner
    ) external override initializer {
        ERC20Upgradeable.__ERC20_init(_name, _symbol);
        OwnableUpgradeable.__Ownable_init();

        underlying = ERC20(_token);
        underlyingUnit = 10 ** uint256(underlying.decimals());

        feeAddress = _feeAddress;
        fee = _fee;
        underlyingStrategy = _strategy;

        transferOwnership(_owner);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender).sub(amount, "ERC20: transfer amount exceeds allowance"));
        _updateUserFeeInfo(recipient, amount, userAvgPrices[sender]);
        return true;
    }


    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        _updateUserFeeInfo(recipient, amount, userAvgPrices[msg.sender]);
        return true;
    }

    /// @notice Deposits the underlying token into the liquidity pool.
    /// @param  depositAmount underlying token amount to deposit
    function deposit(uint256 depositAmount) public {

        require(depositAmount > 0, "ZERO_AMOUNT");
        require(underlying.allowance(msg.sender, address(this)) >= depositAmount, "INSUFFICIENT_ALLOWANCE");

        uint256 toMint = _calculateMintAmount(depositAmount);
        uint256 lpPrice = getPricePerFullShare();

        // Mint LP to sender.
        _mint(msg.sender, toMint);

        _updateUserFeeInfo(msg.sender, toMint, lpPrice);

        // Transfer the tokens from the sender to this contract.
        underlying.safeTransferFrom(msg.sender, address(this), depositAmount);

        emit Deposited(msg.sender, depositAmount);
    }

    /// @notice Redeems LP tokens by burning them and getting back underlying token.
    /// @param  _redeemAmount LP token amount to redeem.
    /// @return redeemedTokens underlying tokens redeemed
    function redeem(uint256 _redeemAmount) public returns (uint256 redeemedTokens) {

        uint256 totalSupply = totalSupply();
        require(totalSupply > 0, "ZERO_SUPPLY");
        require(_redeemAmount > 0, "ZERO_AMOUNT");
        require(_redeemAmount <= balanceOf(msg.sender), "INSUFFICIENT_BALANCE");

        uint256 totalBalance = underlyingBalanceInclStrategy();
        uint256 underlyingBalance = underlyingBalanceInPool();
        uint256 underlyingAmountToWithdraw = totalBalance.mul(_redeemAmount).div(totalSupply);
        uint256 lpPrice = getPricePerFullShare();


        if (underlyingAmountToWithdraw > underlyingBalance) {
            uint256 missingUnderlying = underlyingAmountToWithdraw.sub(underlyingBalance);
            uint256 missingRedeemed = missingUnderlying.mul(totalSupply).div(totalBalance.sub(underlyingBalance));

            redeemedTokens = IStrategy(underlyingStrategy).redeem(
                missingRedeemed, totalSupply, address(this)
            );

            redeemedTokens = Math.min(
                underlyingBalanceInclStrategy()
                .mul(_redeemAmount)
                .div(totalSupply),
                underlyingBalanceInPool()
            );
        } else {
            redeemedTokens = underlyingAmountToWithdraw;
        }

        redeemedTokens = _chargeFee(_redeemAmount, redeemedTokens, lpPrice);
        // Burn LP from sender
        _burn(msg.sender, _redeemAmount);
        // send underlying to sender
        underlying.safeTransfer(msg.sender, redeemedTokens);

        emit Redeemed(msg.sender, redeemedTokens);
    }

    /// @notice Execute a rebalance. Only owner.
    ///         Fails if the rebalance would result into lower APR.
    //  @param  _data rebalance data
    function rebalance(bytes memory _data) external onlyOwner {

        (uint256 _maxInvestmentPerc, address _underlyingStrategy,
        bytes memory _underlyingData) = abi.decode(_data, (uint256, address, bytes));

        require(_maxInvestmentPerc <= FULL_ALLOC, "PERC_HIGHER");
        require(_underlyingStrategy != address(0), "ZERO_ADDR");

        if (underlyingStrategy != _underlyingStrategy) {
            uint256 totalSupply = totalSupply();
            // redeem the full supply from previous strategy
            IStrategy(underlyingStrategy).redeem(totalSupply, totalSupply, address(this));
            // set new strategy
            underlyingStrategy = _underlyingStrategy;
        }

        uint256 poolBalance = underlyingBalanceInPool();
        uint256 investedBalance = IStrategy(underlyingStrategy).investedUnderlyingBalance();
        uint256 underlyingBalance = poolBalance.add(investedBalance);
        // get current investment percentage
        uint256 currentInvestmentPerc = underlyingBalance == 0
            ? 0
            : investedBalance.mul(FULL_ALLOC).div(underlyingBalance);

        uint256 allocationDiff;

        if (_maxInvestmentPerc < currentInvestmentPerc) {
            // redeem the diff
            allocationDiff = (currentInvestmentPerc.sub(_maxInvestmentPerc))
                .mul(underlyingBalance)
                .div(investedBalance);
            if (allocationDiff > MARGIN_ALLOC) {
                IStrategy(underlyingStrategy).redeem(allocationDiff, FULL_ALLOC, address(this));
            }
        } else {
            if (_maxInvestmentPerc > currentInvestmentPerc) {
                // invest the diff
                allocationDiff = poolBalance == 0
                ?   _maxInvestmentPerc
                :   (_maxInvestmentPerc.sub(currentInvestmentPerc))
                    .mul(underlyingBalance)
                    .div(poolBalance);
                if (allocationDiff > MARGIN_ALLOC) {
                    _invest(underlyingStrategy, allocationDiff, poolBalance);
                }
            }
        }

        IStrategy(underlyingStrategy).rebalance(_underlyingData);
    }

    function changeStrategy(address _underlyingStrategy) external onlyOwner {

        require(_underlyingStrategy != address(0), "ZERO_ADDR");
        require(_underlyingStrategy != underlyingStrategy, "NO_CHANGE");

        uint256 totalSupply = totalSupply();
        // redeem the full supply from previous strategy
        IStrategy(underlyingStrategy).redeem(totalSupply, totalSupply, address(this));

        // set new strategy
        underlyingStrategy = _underlyingStrategy;

        // trigger rebalance as next step
    }

    /// @notice APR for the investment
    function getAPR() public view returns (uint256 apr) {
        return IStrategy(underlyingStrategy).getAPR();
    }

    function decimals() public view virtual override returns (uint8) {
        return uint8(underlying.decimals());
    }

    /// @notice Get the balance of the underlying token owned by the pool itself.
    /// @return uint256 underlying balance.
    function underlyingBalanceInPool() public view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    /// @notice Get the total balance of the underlying token owned by the pool and its strategies.
    /// @return total underlying balance.
    function underlyingBalanceInclStrategy() public view returns (uint256) {
        if (underlyingStrategy == address(0)) {
            return underlyingBalanceInPool();
        }

        return underlyingBalanceInPool().add(IStrategy(underlyingStrategy).investedUnderlyingBalance());
    }

    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0
            ? underlyingUnit
            : underlyingUnit.mul(underlyingBalanceInclStrategy()).div(totalSupply());
    }

    /// @notice Calculate the LP token amount that correspondents to the underlying token amount.
    /// @param  depositAmount underlying token amount to deposit.
    /// @return uint256 LP token amount to mint.
    function _calculateMintAmount(uint256 depositAmount) internal view returns (uint256) {
        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) {
            return depositAmount.mul(DEFAULT_LPT_RATE);
        }

        return depositAmount.mul(totalSupply).div(underlyingBalanceInclStrategy());
    }

    function _updateUserFeeInfo(address usr, uint256 qty, uint256 price) private {
        uint256 usrBal = balanceOf(usr);
        userAvgPrices[usr] = userAvgPrices[usr].mul(usrBal.sub(qty)).add(price.mul(qty)).div(usrBal);
    }


    function _chargeFee(uint256 amount, uint256 redeemed, uint256 currPrice) internal returns (uint256) {
        uint256 avgPrice = userAvgPrices[msg.sender];
        if (currPrice < avgPrice) {
            return redeemed;
        }

        uint256 feeDue = amount.mul(currPrice.sub(avgPrice)).mul(fee).div(10**23);
        if (feeDue > 0) {
            underlying.safeTransfer(feeAddress, feeDue);
        }

        return redeemed.sub(feeDue);
    }

    function availableToInvestOut(uint256 _allocation, uint256 _total) public view returns (uint256) {
        uint256 wantInvestInTotal = _total
        .mul(_allocation)
        .div(FULL_ALLOC);

        return wantInvestInTotal <= _total
            ? wantInvestInTotal : _total;
    }

    function _invest(address _strategy, uint256 _allocation, uint256 _total) internal {
        uint256 availableAmount = availableToInvestOut(_allocation, _total);
        if (availableAmount > 0) {
            underlying.safeTransfer(_strategy, availableAmount);
        }
    }
}
