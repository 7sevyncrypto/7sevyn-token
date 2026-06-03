// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./IUniswapV2.sol";

/**
 * 7SEVYN token (matching Whitepaper V14 Final)
 * Key points implemented:
 *  - Total tax default 7% (max 10%) split: 3% reflections, 2% auto-LP, 1% marketing (governance-tunable), 1% salaries (fixed)
 *  - RFI-style reflections
 *  - SwapBack: routes marketing/salaries to wallets, LP share to liquidity
 *  - Anti-whale: maxTx 0.5% supply, maxWallet 1% supply, exemptions
 *  - Trading toggle
 *  - Dev wallet: 6-month lock, announce->execute sell with 4% of dev wallet cap;
 *  - Governance: owner is multisig after deploy; marketing % adjustable within once-per-year window; total tax hard-capped at 10%
 *
 * NOTE: This code is a draft for audit. Test thoroughly on testnet.
 */

contract SevenSevyn is IERC20, IERC20Metadata, Ownable2Step, ReentrancyGuard {
    // --- Transparency events (added) ---
    event MaxTxUpdated(uint256 amount);
    event MaxWalletUpdated(uint256 amount);
    event SwapThresholdUpdated(uint256 amount);
    event ExemptUpdated(
        address account,
        bool limitEx,
        bool feeEx,
        bool reflectEx
    );
    event ReflectionDistributed(uint256 amount);
    // --- LP receiver controls ---
    event LPReceiverSet(address receiver);
    event LPReceiverFrozen();
    event TransferFailed(address to);
    event SwapSlippageBpsUpdated(uint256 bps);

    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Basic metadata
    string private constant _NAME = "7sevyn";
    string private constant _SYMBOL = "7SEVYN";
    uint8 private constant _DECIMALS = 18;

    // Supply (77,000,000,000 * 1e18)
    uint256 private constant _tTotal = 77_000_000_000 * 1e18;

    // RFI variables
    uint256 private _rTotal =
        (type(uint256).max - (type(uint256).max % _tTotal));
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned; // only for excluded accounts
    mapping(address => mapping(address => uint256)) private _allowances;

    // Fees (in basis points, i.e. 100 = 1%)
    uint256 public feeReflectionBP = 300; // 3%
    uint256 public feeLPBP = 200; // 2%
    uint256 public feeMarketingBP = 100; // 1% (governance tunable)
    uint256 public constant FEE_SALARIES_BP = 100; // 1% (fixed)
    uint256 public constant MAX_TOTAL_FEE_BP = 1000; // 10% hard cap

    uint256 public swapSlippageBps = 1000; // 10% default
    uint256 private constant BPS_DENOM = 10_000;

    // Annual change guard for marketing fee
    uint256 public lastTaxChangeTimestamp;

    // Anti-whale
    uint256 public maxTxAmount; // 0.5% of supply
    uint256 public maxWalletAmount; // 1% of supply
    mapping(address => bool) public isLimitExempt;

    // DEX
    IUniswapV2Router02 public router;
    address public pair;

    // Swap/LP
    bool private inSwap;
    uint256 public swapThreshold = 500_000 * 1e18; // tweak on testnet
    address public marketingWallet;
    address public salariesWallet;
    address public immutable reserveWallet;

    // trading
    bool public tradingOpen;

    // Exclusions
    mapping(address => bool) public isFeeExempt;
    mapping(address => bool) public isReflectExempt; // excluded from reflections
    EnumerableSet.AddressSet private _excluded;

    // Dev wallet rules
    address public immutable devWallet;
    uint256 public immutable devLockEnd; // lock duration at deploy

    uint256 public devSellDelay = 24 hours;
    uint256 public devAnnounceTime;
    uint256 public devAnnounceAmount;

    event SwapBack(
        uint256 tokensSwapped,
        uint256 ethForMarketing,
        uint256 ethForSalaries,
        uint256 tokensForLP,
        uint256 ethForLP
    );
    event OpenTrading();
    event FeesUpdated(
        uint256 reflectionBP,
        uint256 lpBP,
        uint256 marketingBP,
        uint256 salariesBP,
        uint256 updatedAt
    );
    event FeesOld(
        uint256 reflectionBP,
        uint256 lpBP,
        uint256 marketingBP,
        uint256 salariesBP
    );
    event DevSellAnnounced(uint256 amount, uint256 executeAfter);
    event DevSellExecuted(uint256 amount);

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address _router,
        address _marketing,
        address _salaries,
        address _dev,
        address _reserve,
        uint256 _devLockSeconds
    ) Ownable(msg.sender) {
        require(
            _router != address(0) &&
                _marketing != address(0) &&
                _salaries != address(0) &&
                _dev != address(0) &&
                _reserve != address(0),
            "zero addr"
        );

        require(_devLockSeconds >= 180 days, "dev lock too short");

        router = IUniswapV2Router02(_router);
        marketingWallet = _marketing;
        salariesWallet = _salaries;
        devWallet = _dev;
        reserveWallet = _reserve;

        address _pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );
        pair = _pair;

        // RFI: assign entire reflection supply to deployer (owner)
        _rOwned[msg.sender] = _rTotal;

        // Anti-whale defaults
        maxTxAmount = (_tTotal * 5) / 1000; // 0.5%
        maxWalletAmount = (_tTotal * 10) / 1000; // 1%

        // Exemptions
        isLimitExempt[msg.sender] = true;
        isLimitExempt[address(this)] = true;
        isLimitExempt[_pair] = true;
        isLimitExempt[_marketing] = true;
        isLimitExempt[_salaries] = true;
        isLimitExempt[_dev] = true;
        isLimitExempt[_reserve] = true;

        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;
        isFeeExempt[_marketing] = true;
        isFeeExempt[_salaries] = true;

        // reflection exclusion for contract
        _excludeFromReward(address(this));

        // Dev lock
        devLockEnd = block.timestamp + _devLockSeconds;
        lastTaxChangeTimestamp = block.timestamp;

        emit Transfer(address(0), msg.sender, _tTotal);
    }

    // IERC20Metadata
    function name() external pure override returns (string memory) {
        return _NAME;
    }
    function symbol() external pure override returns (string memory) {
        return _SYMBOL;
    }
    function decimals() external pure override returns (uint8) {
        return _DECIMALS;
    }

    // IERC20
    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (isReflectExempt[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 value
    ) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 curAllowance = _allowances[sender][msg.sender];
        require(curAllowance >= amount, "allowance");
        _allowances[sender][msg.sender] = curAllowance - amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    // Reflection helpers
    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) public view returns (uint256) {
        require(tAmount <= _tTotal, "too big");
        (uint256 rAmount, uint256 rTransferAmount, , , , ) = _getValues(
            tAmount
        );
        if (deductTransferFee) {
            return rTransferAmount;
        } else {
            return rAmount;
        }
    }

    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        require(rAmount <= _rTotal, "too much");
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal -= rFee;
        // tFee is not tracked (holders benefit via rTotal decrease)
        emit ReflectionDistributed(tFee); // optional visibility of reflection
    }

    // Trading control
    function openTrading() external onlyOwner {
        require(!tradingOpen, "open");
        tradingOpen = true;
        emit OpenTrading();
    }

    // Governance updates
    function updateAdjustableAllocations(
        uint256 newReflectionFee,
        uint256 newMarketingFee,
        uint256 newLPFee
    ) external onlyOwner {
        require(
            block.timestamp >= lastTaxChangeTimestamp + 365 days,
            "once/year"
        );
        // salaries is fixed at 1% and we keep others at defaults for now
        uint256 total = newReflectionFee +
            FEE_SALARIES_BP +
            newMarketingFee +
            newLPFee;
        require(total <= MAX_TOTAL_FEE_BP, "fee cap");
        lastTaxChangeTimestamp = block.timestamp;

        emit FeesOld(feeReflectionBP, feeLPBP, feeMarketingBP, FEE_SALARIES_BP);

        feeReflectionBP = newReflectionFee;
        feeMarketingBP = newMarketingFee;
        feeLPBP = newLPFee;

        emit FeesUpdated(
            feeReflectionBP,
            feeLPBP,
            feeMarketingBP,
            FEE_SALARIES_BP,
            block.timestamp
        );
    }

    function setSwapSlippageBps(uint256 bps) external onlyOwner {
        require(bps >= 100 && bps <= 3000, "too low or high");
        swapSlippageBps = bps;
        emit SwapSlippageBpsUpdated(bps);
    }

    function setSwapThreshold(uint256 amount) external onlyOwner {
        uint256 min = 100000e18;
        uint256 max = (totalSupply() * 100) / BPS_DENOM; // 1%

        require(amount >= min, "swapThreshold too low");
        require(amount <= max, "swapThreshold too high");

        swapThreshold = amount;
        emit SwapThresholdUpdated(amount);
    }
    function setMaxTx(uint256 amount) external onlyOwner {
        uint256 minMaxTx = (totalSupply() * 10) / BPS_DENOM;
        require(amount >= minMaxTx, "maxTx too low");
        maxTxAmount = amount;
        emit MaxTxUpdated(amount);
    }
    function setMaxWallet(uint256 amount) external onlyOwner {
        uint256 minMaxWallet = (totalSupply() * 20) / BPS_DENOM;
        require(amount >= minMaxWallet, "maxWallet too low");
        maxWalletAmount = amount;
        emit MaxWalletUpdated(amount);
    }
    function setExempt(
        address account,
        bool limitEx,
        bool feeEx,
        bool reflectEx
    ) external onlyOwner {
        require(account != devWallet, "dev wallet cannot be fee exempt");
        isLimitExempt[account] = limitEx;
        isFeeExempt[account] = feeEx;
        if (reflectEx && !isReflectExempt[account]) {
            _excludeFromReward(account);
        } else if (!reflectEx && isReflectExempt[account]) {
            _includeInReward(account);
        }
        emit ExemptUpdated(account, limitEx, feeEx, reflectEx);
    }

    // Dev sell announce/execute
    function announceDevSell(uint256 amount) external {
        require(msg.sender == devWallet, "dev only");
        require(block.timestamp >= devLockEnd, "dev locked");
        require(amount > 0, "zero");
        devAnnounceTime = block.timestamp;
        devAnnounceAmount = amount;
        emit DevSellAnnounced(amount, block.timestamp + devSellDelay);
    }

    function executeDevSell() external nonReentrant swapping {
        require(msg.sender == devWallet, "dev only");
        require(block.timestamp >= devLockEnd, "dev locked");
        require(
            devAnnounceTime > 0 &&
                block.timestamp >= devAnnounceTime + devSellDelay,
            "too early"
        );

        uint256 devBal = balanceOf(devWallet);
        uint256 maxPerSell = (devBal * 400) / BPS_DENOM; // 4%
        require(devAnnounceAmount <= maxPerSell, "exceeds 4% of dev wallet");

        // transfer from dev to contract
        _transfer(devWallet, address(this), devAnnounceAmount);

        // sell remaining tokens for ETH (BNB) to dev
        _swapTokensForETH(devAnnounceAmount, devWallet);

        // reset
        emit DevSellExecuted(devAnnounceAmount);
        devAnnounceTime = 0;
        devAnnounceAmount = 0;
    }

    // Transfer core
    function _transfer(address from, address to, uint256 tAmount) internal {
        require(from != address(0) && to != address(0), "zero");
        if (!isLimitExempt[from] && !isLimitExempt[to]) {
            require(tAmount <= maxTxAmount, "maxTx");
        }
        if (!isLimitExempt[to]) {
            require(balanceOf(to) + tAmount <= maxWalletAmount, "maxWallet");
        }
        require(
            tradingOpen || isFeeExempt[from] || isFeeExempt[to],
            "trading closed"
        );

        // SwapBack on sells to pair
        if (!inSwap && to == pair) {
            uint256 contractTokenBal = balanceOf(address(this));

            if (contractTokenBal >= swapThreshold) {
                _swapBack(contractTokenBal);
            }
        }
        bool takeFee = !(isFeeExempt[from] || isFeeExempt[to]);
        if (takeFee) {
            _tokenTransfer(from, to, tAmount);
        } else {
            _basicTransfer(from, to, tAmount);
        }
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 tAmount
    ) internal {
        // no fees/reflections
        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount * currentRate;

        if (isReflectExempt[sender]) _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;

        if (isReflectExempt[recipient]) _tOwned[recipient] += tAmount;
        _rOwned[recipient] += rAmount;

        emit Transfer(sender, recipient, tAmount);
    }

    function _internalTokenLogic(
        uint256 tAmount
    ) private returns (uint256, uint256, uint256, uint256, uint256) {
        // compute fees
        uint256 tFeeReflect = (tAmount * feeReflectionBP) / BPS_DENOM;
        uint256 tFeeLP = (tAmount * feeLPBP) / BPS_DENOM;
        uint256 tFeeMarketing = (tAmount * feeMarketingBP) / BPS_DENOM;
        uint256 tFeeSalaries = (tAmount * FEE_SALARIES_BP) / BPS_DENOM;
        uint256 tFeeTotal = tFeeReflect + tFeeLP + tFeeMarketing + tFeeSalaries;

        uint256 tTransferAmount = tAmount - tFeeTotal;

        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount * currentRate;
        uint256 rFeeReflect = tFeeReflect * currentRate;
        uint256 rTransferAmount = (tTransferAmount) * currentRate;

        _reflectFee(rFeeReflect, tFeeReflect);

        // move fee tokens to contract for later processing (LP/marketing/salaries)
        uint256 tToContract = tFeeLP + tFeeMarketing + tFeeSalaries;
        return (
            rAmount,
            rTransferAmount,
            tTransferAmount,
            tToContract,
            currentRate
        );
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount
    ) internal {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tTransferAmount,
            uint256 tToContract,
            uint256 currentRate
        ) = _internalTokenLogic(tAmount);

        if (isReflectExempt[sender]) {
            _tOwned[sender] -= tAmount;
        }
        _rOwned[sender] -= rAmount;
        if (isReflectExempt[recipient]) {
            _tOwned[recipient] += tTransferAmount;
        }
        _rOwned[recipient] += rTransferAmount;

        // move fee tokens to contract for later processing (LP/marketing/salaries)
        if (tToContract > 0) {
            uint256 rToContract = tToContract * currentRate;
            _rOwned[address(this)] += rToContract;
            if (isReflectExempt[address(this)])
                _tOwned[address(this)] += tToContract;
            emit Transfer(sender, address(this), tToContract);
        }

        emit Transfer(sender, recipient, tTransferAmount);
    }

    // SwapBack: swap marketing + salaries + half of LP for ETH, then add liquidity
    function _swapBack(uint256 totalToken) internal swapping {
        uint256 totalFee = feeLPBP + feeMarketingBP + FEE_SALARIES_BP;
        if (totalFee == 0) return;
        uint256 lpTokens = (totalToken * feeLPBP) / totalFee;

        uint256 halfLP = lpTokens / 2;
        uint256 tokensToSwap = totalToken - halfLP;
        uint256 marketingTokens = (tokensToSwap * feeMarketingBP) / totalFee;
        uint256 salaryTokens = (tokensToSwap * FEE_SALARIES_BP) / totalFee;
        uint256 balanceBefore = address(this).balance;
        _swapTokensForETH(tokensToSwap, address(this));
        uint256 ethGained = address(this).balance - balanceBefore;

        if (tokensToSwap == 0) return;
        uint256 ethForMarketing = (ethGained * marketingTokens) / tokensToSwap;
        uint256 ethForSalaries = (ethGained * salaryTokens) / tokensToSwap;
        uint256 ethForLP = ethGained - ethForMarketing - ethForSalaries;

        // pay wallets

        if (ethForMarketing > 0) {
            (bool success, ) = payable(marketingWallet).call{
                value: ethForMarketing
            }("");
            if (!success) {
                emit TransferFailed(marketingWallet);
            }
        }

        if (ethForSalaries > 0) {
            (bool success, ) = payable(salariesWallet).call{
                value: ethForSalaries
            }("");
            if (!success) {
                emit TransferFailed(salariesWallet);
            }
        }

        // add liquidity
        if (halfLP > 0 && ethForLP > 0) {
            _addLiquidity(halfLP, ethForLP);
        }

        emit SwapBack(
            tokensToSwap,
            ethForMarketing,
            ethForSalaries,
            halfLP,
            ethForLP
        );
    }

    function _swapTokensForETH(uint256 tokenAmount, address to) internal {
        uint256 currentRate = _getRate();
        // remove reflective portion from contract rOwned, then approve router and swap
        uint256 rAmount = tokenAmount * currentRate;
        if (_rOwned[address(this)] < rAmount) return; // safety

        _approve(address(this), address(router), tokenAmount);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        uint256[] memory amountsOut = router.getAmountsOut(tokenAmount, path);
        uint256 expectedOut = amountsOut[1];

        uint256 amountOutMin = (expectedOut * (BPS_DENOM - swapSlippageBps)) /
            BPS_DENOM;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            amountOutMin,
            path,
            to,
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        _approve(address(this), address(router), tokenAmount);
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            lpRecipient(), // LP receiver at add time (should be locker address/process after)
            block.timestamp
        );
    }

    // Exclude/include from reflections
    function _excludeFromReward(address account) internal {
        require(!isReflectExempt[account], "already");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        isReflectExempt[account] = true;
        _excluded.add(account);
    }

    function _includeInReward(address account) internal {
        require(isReflectExempt[account], "not excluded");

        uint256 currentRate = _getRate();
        _rOwned[account] = _tOwned[account] * currentRate;

        _tOwned[account] = 0;
        isReflectExempt[account] = false;
        _excluded.remove(account);
    }

    // Approve helper

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    // Rate helpers
    function _getValues(
        uint256 tAmount
    )
        private
        view
        returns (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        )
    {
        uint256 tFeeReflect = (tAmount * feeReflectionBP) / BPS_DENOM;
        uint256 tOther = (tAmount *
            (feeLPBP + feeMarketingBP + FEE_SALARIES_BP)) / BPS_DENOM;
        tTransferAmount = tAmount - tFeeReflect - tOther;
        tFee = tFeeReflect;
        tLiquidity = tOther;
        uint256 currentRate = _getRate();
        rAmount = tAmount * currentRate;
        rFee = tFeeReflect * currentRate;
        rTransferAmount = (tTransferAmount) * currentRate;
    }

    function _getRate() private view returns (uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        uint256 rTotalDivTTotal = _rTotal / _tTotal;

        //safety check for zero address
        if (_rOwned[address(0)] > rSupply) {
            return rTotalDivTTotal;
        }

        // exclude zero/contract if needed
        uint256 length = _excluded.length();
        for (uint256 i = 0; i < length; i++) {
            address account = _excluded.at(i);

            if (_rOwned[account] > rSupply || _tOwned[account] > tSupply) {
                return rTotalDivTTotal;
            }

            rSupply -= _rOwned[account];
            tSupply -= _tOwned[account];
        }
        if (tSupply == 0 || rSupply == 0) {
            return rTotalDivTTotal;
        }
        if (rSupply < rTotalDivTTotal) {
            return rTotalDivTTotal;
        }
        return rSupply / tSupply;
    }

    // receive ETH
    receive() external payable {}

    // === LP Receiver (optional safety) ===
    address public lpReceiver;
    bool public lpReceiverFrozen;

    function lpRecipient() public view returns (address) {
        return lpReceiver == address(0) ? owner() : lpReceiver;
    }

    function setLPReceiver(address receiver) external onlyOwner {
        require(!lpReceiverFrozen, "frozen");
        require(receiver != address(0), "zero");
        lpReceiver = receiver;
        emit LPReceiverSet(receiver);
    }

    function freezeLPReceiver() external onlyOwner {
        lpReceiverFrozen = true;
        emit LPReceiverFrozen();
    }
}
