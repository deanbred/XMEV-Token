// SPDX-License-Identifier: MIT
/*
*  BaseDev DEX
*  Web: https://basedev.tech/
*  X: @basedev777
*/
pragma solidity = 0.8.18;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IERC20Metadata is IERC20 {

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}


contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}


contract BaseDev is ERC20, Ownable {
    uint256 public constant FEE_DENOMINATOR = 1e4;
    uint256 public constant MAX_FEE = 1000;

    uint256 public farmsBuyFee;
    uint256 public stakingBuyFee;
    uint256 public treasuryBuyFee;
    uint256 public totalBuyFee;

    uint256 public farmsSellFee;
    uint256 public stakingSellFee;
    uint256 public treasurySellFee;
    uint256 public totalSellFee;

    address public farmsFeeRecipient;
    address public stakingFeeRecipient;
    address public treasuryFeeRecipient;

    bool public tradingEnabled;
    uint256 public tradingEnabledTimestamp = 0;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool public swappingFeesEnabled;
    bool public isSwappingFees;
    uint256 public swapFeesAtAmount;
    uint256 public maxSwapFeesAmount;
    uint256 public maxWalletAmount;

    uint256 public sniperBuyBaseFee = 160;
    uint256 public sniperBuyFeeDecayPeriod = 15 minutes;
    bool public sniperBuyFeeEnabled = true;

    uint256 public sniperSellBaseFee = 160;
    uint256 public sniperSellFeeDecayPeriod = 15 minutes;
    bool public sniperSellFeeEnabled = true;

    bool public maxWalletEnabled;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) internal _isExcludedFromMaxWallet;

    event BuyFeeUpdated(uint256 _fee, uint256 _previousFee);
    event SellFeeUpdated(uint256 _fee, uint256 _previousFee);
    event AddressExcludedFromFees(address _address);
    event AddressIncludedInFees(address _address);

    error TradingNotEnabled();
    error TradingAlreadyEnabled();
    error MaxWalletReached();
    error FeeTooHigh();
    error TransferFailed();
    error ArrayLengthMismatch();

    constructor(
        address _farms,
        address _staking,
        address _treasury
    ) ERC20("BaseDev", "BASEDEV") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x4cf76043B3f97ba06917cBd90F9e3A2AAC1B306e);
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());    

        farmsFeeRecipient = address(_farms);
        stakingFeeRecipient = address(_staking);
        treasuryFeeRecipient = address(_treasury);

        isExcludedFromFee[farmsFeeRecipient] = true;
        isExcludedFromFee[stakingFeeRecipient] = true;
        isExcludedFromFee[treasuryFeeRecipient] = true;             

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[address(uniswapV2Router)] = true;

        _isExcludedFromMaxWallet[owner()] = true;
        _isExcludedFromMaxWallet[address(this)] = true;
        _isExcludedFromMaxWallet[uniswapV2Pair] = true;     

        farmsBuyFee = 111;
        stakingBuyFee = 111;
        treasuryBuyFee = 111;
        setBuyFees(farmsBuyFee, stakingBuyFee, treasuryBuyFee);

        farmsSellFee = 111;
        stakingSellFee = 111;
        treasurySellFee = 111;
        setSellFees(farmsSellFee, stakingSellFee, treasurySellFee);

        _mint(owner(), 7000000000 * 10 ** decimals());
        _mint(farmsFeeRecipient, 222222222 * 10 ** decimals());
        _mint(stakingFeeRecipient, 222222222 * 10 ** decimals());
        _mint(treasuryFeeRecipient, 333333333 * 10 ** decimals());

        swapFeesAtAmount = (totalSupply() * 3) / 1e5;
        maxSwapFeesAmount = (totalSupply() * 4) / 1e5;
        maxWalletAmount = (totalSupply() * 49) / 1e4;
        maxWalletEnabled = true;      
    }

    function _shouldTakeTransferTax(
        address sender,
        address recipient
    ) internal view returns (bool) {
        if (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) {
            return false;
        }

        return
            (sender == uniswapV2Pair || recipient == uniswapV2Pair);
    }

    function sniperBuyFee() public view returns (uint256) {
        if (!sniperBuyFeeEnabled) {
            return 0;
        }

        uint256 timeSinceLaunch = block.timestamp - tradingEnabledTimestamp;

        if (timeSinceLaunch >= sniperBuyFeeDecayPeriod) {
            return 0;
        }

        return
            sniperBuyBaseFee -
            (sniperBuyBaseFee * timeSinceLaunch) /
            sniperBuyFeeDecayPeriod;
    }

    function sniperSellFee() public view returns (uint256) {
        if (!sniperSellFeeEnabled) {
            return 0;
        }

        uint256 timeSinceLaunch = block.timestamp - tradingEnabledTimestamp;

        if (timeSinceLaunch >= sniperSellFeeDecayPeriod) {
            return 0;
        }

        return
            sniperSellBaseFee -
            (sniperSellBaseFee * timeSinceLaunch) /
            sniperSellFeeDecayPeriod;
    }

    function _takeBuyFee(
        address sender,
        uint256 amount
    ) internal returns (uint256) {
        if (totalBuyFee == 0) return 0;

        uint256 totalFeeAmount = (amount * totalBuyFee) / FEE_DENOMINATOR;

        if (totalFeeAmount == 0) return 0;

        uint256 farmsFeeAmount = (totalFeeAmount * farmsBuyFee) / totalBuyFee;
        uint256 stakingFeeAmount = (totalFeeAmount * stakingBuyFee) /
            totalBuyFee;
        uint256 treasuryFeeAmount = totalFeeAmount -
            farmsFeeAmount -
            stakingFeeAmount;

        if (farmsFeeAmount > 0)
            super._transfer(sender, farmsFeeRecipient, farmsFeeAmount);

        if (stakingFeeAmount > 0)
            super._transfer(sender, stakingFeeRecipient, stakingFeeAmount);

        if (treasuryFeeAmount > 0)
            super._transfer(sender, address(this), treasuryFeeAmount);

        return totalFeeAmount;
    }

    function _takeSellFee(
        address sender,
        uint256 amount
    ) internal returns (uint256) {
        if (totalSellFee == 0) return 0;

        uint256 totalFeeAmount = (amount * totalSellFee) / FEE_DENOMINATOR;

        if (totalFeeAmount == 0) return 0;

        uint256 farmsFeeAmount = (totalFeeAmount * farmsSellFee) / totalSellFee;
        uint256 stakingFeeAmount = (totalFeeAmount * stakingSellFee) /
            totalSellFee;
        uint256 treasuryFeeAmount = totalFeeAmount -
            farmsFeeAmount -
            stakingFeeAmount;

        if (farmsFeeAmount > 0)
            super._transfer(sender, farmsFeeRecipient, farmsFeeAmount);

        if (stakingFeeAmount > 0)
            super._transfer(sender, stakingFeeRecipient, stakingFeeAmount);

        if (treasuryFeeAmount > 0)
            super._transfer(sender, address(this), treasuryFeeAmount);

        return totalFeeAmount;
    }

    function _takeSniperBuyFee(
        address sender,
        uint256 amount
    ) internal returns (uint256) {
        uint256 totalFeeAmount = (amount * sniperBuyFee()) / FEE_DENOMINATOR;

        if (totalFeeAmount > 0)
            super._transfer(sender, address(this), totalFeeAmount);

        return totalFeeAmount;
    }

    function _takeSniperSellFee(
        address sender,
        uint256 amount
    ) internal returns (uint256) {
        uint256 totalFeeAmount = (amount * sniperSellFee()) / FEE_DENOMINATOR;

        if (totalFeeAmount > 0)
            super._transfer(sender, address(this), totalFeeAmount);

        return totalFeeAmount;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (
            !tradingEnabled &&
            !isExcludedFromFee[sender] &&
            !isExcludedFromFee[recipient]
        ) {
            revert TradingNotEnabled();
        }

        if (
            maxWalletEnabled &&
            !isExcludedFromMaxWallet(recipient) &&
            balanceOf(recipient) + amount > maxWalletAmount
        ) revert MaxWalletReached();

        bool takeFee = !isSwappingFees &&
            _shouldTakeTransferTax(sender, recipient);

        bool isBuy = false;
        if (sender == uniswapV2Pair) {
            isBuy = true;
        }

        bool isSell = false;
        if (recipient == uniswapV2Pair) {
            isSell = true;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwapFees = contractTokenBalance >= swapFeesAtAmount;
        bool isEOATransfer = sender.code.length == 0 &&
            recipient.code.length == 0;

        if (
            canSwapFees &&
            swappingFeesEnabled &&
            !isSwappingFees &&
            (isSell || isEOATransfer) &&
            !isExcludedFromFee[sender] &&
            !isExcludedFromFee[recipient]
        ) {
            isSwappingFees = true;
            _swapFees();
            isSwappingFees = false;
        }

        uint256 totalFeeAmount;
        if (takeFee) {
            if (isSell) {
                totalFeeAmount = _takeSellFee(sender, amount);
                totalFeeAmount += _takeSniperSellFee(sender, amount);
            } else if (isBuy) {
                totalFeeAmount = _takeBuyFee(sender, amount);
                totalFeeAmount += _takeSniperBuyFee(sender, amount);
            }
        }

        super._transfer(sender, recipient, amount - totalFeeAmount);
    }

    function _swapFees() internal {
        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 amountToSwap = contractTokenBalance > maxSwapFeesAmount
            ? maxSwapFeesAmount
            : contractTokenBalance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), amountToSwap);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function withdrawStuckEth(uint256 amount) public onlyOwner {
        (bool success, ) = address(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function withdrawStuckEth() public onlyOwner {
        withdrawStuckEth(address(this).balance);
    }

    function withdrawStuckTokens(
        IERC20 token,
        uint256 amount
    ) public onlyOwner {
        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    function withdrawStuckTokens(IERC20 token) public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        withdrawStuckTokens(token, balance);
    }

    function airdropHolders(
        address[] memory wallets,
        uint256[] memory amounts
    ) external onlyOwner {
        if (wallets.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];
            uint256 amount = amounts[i];
            _transfer(msg.sender, wallet, amount);
        }
    }

    function isExcludedFromMaxWallet(
        address account
    ) public view returns (bool) {
        return _isExcludedFromMaxWallet[account];
    }

    function excludeFromMaxWallet(address account) external onlyOwner {
        _isExcludedFromMaxWallet[account] = true;
    }

    function includeInMaxWallet(address account) external onlyOwner {
        _isExcludedFromMaxWallet[account] = false;
    }

    function setMaxWalletEnabled(bool enabled) external onlyOwner {
        maxWalletEnabled = enabled;
    }

    function setMaxWalletAmount(uint256 amount) external onlyOwner {
        maxWalletAmount = amount;
    }

    function excludeFromFee(address _account) external onlyOwner {
        isExcludedFromFee[_account] = true;
        emit AddressExcludedFromFees(_account);
    }

    function includeInFee(address _account) external onlyOwner {
        isExcludedFromFee[_account] = false;
        emit AddressIncludedInFees(_account);
    }

    function setFarmsFeeRecipient(address _account) external onlyOwner {
        require(_account != address(0));
        farmsFeeRecipient = _account;
        isExcludedFromFee[_account] = true;
    }

    function setStakingFeeRecipient(address _account) external onlyOwner {
        require(_account != address(0));
        stakingFeeRecipient = _account;
        isExcludedFromFee[_account] = true;
    }

    function setTreasuryFeeRecipient(address _account) external onlyOwner {
        require(_account != address(0));
        treasuryFeeRecipient = _account;
         isExcludedFromFee[_account] = true;   
    }

    function setBuyFees(
        uint256 _farmsBuyFee,
        uint256 _stakingBuyFee,
        uint256 _treasuryBuyFee
    ) public onlyOwner {
        if (
            _farmsBuyFee + _stakingBuyFee + _treasuryBuyFee >
            MAX_FEE
        ) {
            revert FeeTooHigh();
        }

        farmsBuyFee = _farmsBuyFee;
        stakingBuyFee = _stakingBuyFee;
        treasuryBuyFee = _treasuryBuyFee;
        totalBuyFee = farmsBuyFee + stakingBuyFee + treasuryBuyFee;
    }

    function setSellFees(
        uint256 _farmsSellFee,
        uint256 _stakingSellFee,
        uint256 _treasurySellFee
    ) public onlyOwner {
        if (
            _farmsSellFee + _stakingSellFee + _treasurySellFee >
            MAX_FEE
        ) {
            revert FeeTooHigh();
        }

        farmsSellFee = _farmsSellFee;
        stakingSellFee = _stakingSellFee;
        treasurySellFee = _treasurySellFee;
        totalSellFee =
            farmsSellFee +
            stakingSellFee +
            treasurySellFee;
    }

    function setSniperBuyFeeEnabled(
        bool _sniperBuyFeeEnabled
    ) public onlyOwner {
        sniperBuyFeeEnabled = _sniperBuyFeeEnabled;
    }

    function setSniperSellFeeEnabled(
        bool _sniperSellFeeEnabled
    ) public onlyOwner {
        sniperSellFeeEnabled = _sniperSellFeeEnabled;
    }

    function setSwapFeesAtAmount(uint256 _swapFeesAtAmount) public onlyOwner {
        swapFeesAtAmount = _swapFeesAtAmount;
    }

    function setMaxSwapFeesAmount(uint256 _maxSwapFeesAmount) public onlyOwner {
        maxSwapFeesAmount = _maxSwapFeesAmount;
    }

    function setSwappingFeesEnabled(
        bool _swappingFeesEnabled
    ) public onlyOwner {
        swappingFeesEnabled = _swappingFeesEnabled;
    }

    function enableTrading() public onlyOwner {
        if (tradingEnabled) revert TradingAlreadyEnabled();
        tradingEnabled = true;

        if (tradingEnabledTimestamp < block.timestamp) {
            tradingEnabledTimestamp = block.timestamp;
        }

        swappingFeesEnabled = true;
    }
    
    receive() external payable {}
}