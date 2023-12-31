// SPDX-License-Identifier: MIT
/*
  XMEV2 is the V2 release of the AntiMEV token 
  
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

contract Ownable is Context {
  address private _owner;
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  constructor() {
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
  }

  function owner() public view returns (address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(_owner == _msgSender(), "Ownable: caller is not the owner");
    _;
  }

  function renounceOwnership() public virtual onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
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

contract XMEV2 is Context, IERC20, Ownable {
  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  mapping(address => bool) private _isExcludedFromFee;
  mapping(address => uint256) private _lastTxBlock;
  address payable private _devWallet;
  address payable private _burnWallet;
  address payable private _airdropWallet;

  uint8 private constant _decimals = 18;
  uint256 private constant _tTotal = 1123581321 * 10 ** _decimals;
  string private constant _name = unicode"AntiMEV2";
  string private constant _symbol = unicode"XMEV2";
  uint256 public _maxTxn = 2000000 * 10 ** _decimals;
  uint256 public _maxWalletSize = 4000000 * 10 ** _decimals;
  uint256 public _taxSwapThreshold = 25000 * 10 ** _decimals;
  uint256 public _maxTaxSwap = 500000 * 10 ** _decimals;

  IUniswapV2Router02 private uniswapV2Router;
  address public uniswapV2Pair;
  bool private tradingOpen;
  bool private inSwap = false;
  bool private swapEnabled = false;
  uint256 public tradingEnabledTimestamp = 0;

  bool private _detectMEV = true;
  uint256 public _gasDelta = 25; // increase in gas price to be considered bribe
  uint256 public _avgGasPrice = 1 * 10 ** 9; // initial rolling average gas price
  uint256 private _maxSample = 20; // blocks used to calculate average gas price
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
    _balances[_msgSender()] = (_tTotal * 880) / 1000;
    _balances[_devWallet] = (_tTotal * 48) / 1000;
    _balances[_burnWallet] = (_tTotal * 38) / 1000;
    _balances[_airdropWallet] = (_tTotal * 34) / 1000;

    _isExcludedFromFee[address(this)] = true;
    _isExcludedFromFee[_msgSender()] = true;
    _isExcludedFromFee[_devWallet] = true;
    _isExcludedFromFee[_burnWallet] = true;
    _isExcludedFromFee[_airdropWallet] = true;
  }

  function setMEV(
    bool detectMEV,
    uint256 gasDelta,
    uint256 maxSample,
    uint256 avgGasPrice
  ) external onlyOwner {
    _detectMEV = detectMEV;
    _gasDelta = gasDelta;
    _maxSample = maxSample;
    _avgGasPrice = avgGasPrice;
  }

  function airdropHolders(
    address[] memory wallets,
    uint256[] memory amounts
  ) external onlyOwner {
    if (wallets.length != amounts.length) {
      revert("Mismatched lengths");
    }
    for (uint256 i = 0; i < wallets.length; i++) {
      address wallet = wallets[i];
      uint256 amount = amounts[i];
      _transfer(msg.sender, wallet, amount);
    }
  }

  function setLimits(
    uint256 maxTxn,
    uint256 maxWalletSize,
    uint256 taxSwapThreshold,
    uint256 maxTaxSwap
  ) external onlyOwner {
    _maxTxn = maxTxn;
    _maxWalletSize = maxWalletSize;
    _taxSwapThreshold = taxSwapThreshold;
    _maxTaxSwap = maxTaxSwap;
  }

  function setWallets(
    address devWallet,
    address burnWallet,
    address airdropWallet
  ) external onlyOwner {
    _devWallet = payable(devWallet);
    _burnWallet = payable(burnWallet);
    _airdropWallet = payable(airdropWallet);
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

  function totalSupply() public pure override returns (uint256) {
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
      if (_detectMEV) {
        // test for sandwich attack
        if (to != address(uniswapV2Router) && to != address(uniswapV2Pair)) {
          if (_lastTxBlock[tx.origin] == block.number) {
            revert("Sandwich Attack Detected");
          }
          _lastTxBlock[tx.origin] = block.number;
        }
        // calculate rolling average gas price
        if (_txCounter == _maxSample) {
          _txCounter = 1;
        } else {
          _txCounter += 1;
        }
        _avgGasPrice =
          (_avgGasPrice * (_txCounter - 1)) /
          _txCounter +
          tx.gasprice /
          _txCounter;
        // test for gas bribe (front-run)
        if (tx.gasprice >= _avgGasPrice + (_avgGasPrice * (_gasDelta / 100))) {
          revert("AntiMEV: Detected gas bribe, possible front-run");
        }
      }

      if (
        from == uniswapV2Pair &&
        to != address(uniswapV2Router) &&
        !_isExcludedFromFee[to]
      ) {
        if (amount > _maxTxn) {
          revert("Exceeds maxTxn");
        }
        if (balanceOf(to) + amount > _maxWalletSize) {
          revert("Exceeds maxWalletSize");
        }
      }

      if (to == uniswapV2Pair && from != address(this)) {
        if (amount > _maxTxn) {
          revert("Exceeds maxTxn");
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
      taxAmount = (amount * 1) / 100;
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

  function withdrawStuckEth() public onlyOwner {
    withdrawStuckEth(address(this).balance);
  }

  function withdrawStuckTokens(IERC20 token, uint256 amount) public onlyOwner {
    bool success = token.transfer(msg.sender, amount);
    if (!success) revert("Transfer Failed");
  }

  function withdrawStuckTokens(IERC20 token) public onlyOwner {
    uint256 balance = token.balanceOf(address(this));
    withdrawStuckTokens(token, balance);
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
    tradingEnabledTimestamp = block.timestamp;
    tradingOpen = true;
  }

  receive() external payable {}
}
