// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
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
}

contract FINU is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private bots;
    mapping (address => uint) private cooldown;
    uint256 private _tTotal; // total supply
    
    uint256 private _feeAddr; // team fee
    address payable private _treasuryWallet; // treasury wallet address
    address payable private _yieldWallet; // yield wallet address
    address payable private _feeAddrWallet1; // fee wallet1 address
    address payable private _feeAddrWallet2; //fee wallet2 address
    
    string private constant _name = "First Inu v2";
    string private constant _symbol = "FINUv2";
    uint8 private constant _decimals = 9;
    
    IUniswapV2Router02 private uniswapV2Router;
    address private _pancakeSwapRouterAddress;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    bool private cooldownEnabled = false;
    uint256 private _maxTxAmount = _tTotal;
    event MaxTxAmountUpdated(uint _maxTxAmount);
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
    constructor (
        address treasuryWalletAddress, 
        address yieldWalletAddress, 
        address feeAddrWallet1, 
        address feeAddrWallet2,
        address pancakeSwapRouterAddress
    ) {
        _treasuryWallet = payable(treasuryWalletAddress);
        _yieldWallet = payable(yieldWalletAddress);
        _feeAddrWallet1 = payable(feeAddrWallet1);
        _feeAddrWallet2 = payable(feeAddrWallet2);
        _feeAddr = 0;

        _pancakeSwapRouterAddress = pancakeSwapRouterAddress;

        _mint(msg.sender, 1200000000000000 * 10**9);
        emit Transfer(msg.sender, _msgSender(), _tTotal);
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

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        _feeAddr = 0;
        if (from != owner() && to != owner() && msg.sender != address(this)) {
            require(!bots[from] && !bots[to]);
            if (from == uniswapV2Pair && to != address(uniswapV2Router)  && cooldownEnabled) {
                // Cooldown
                require(amount <= _maxTxAmount);
                require(cooldown[to] < block.timestamp);
                cooldown[to] = block.timestamp + (30 seconds);
            }
            
            
            if (to == uniswapV2Pair && from != address(uniswapV2Router)) {
                _feeAddr = 10;

                uint256 contractTokenBalance = balanceOf(address(this));
                if (!inSwap && from != uniswapV2Pair && swapEnabled) {
                    uint256 amountForFinu = contractTokenBalance.div(10).mul(2);
                    uint256 amountForETH = contractTokenBalance - amountForFinu;

                    _balances[_yieldWallet] += amountForFinu; // send yield finu to yield wallet

                    swapTokensForEth(amountForETH);
                    uint256 contractETHBalance = address(this).balance;
                    if(contractETHBalance > 0) {
                        sendETHToFee(address(this).balance);
                    }
                }
            }
        }
		
        _tokenTransfer(from,to,amount);
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        _transferStandard(sender, recipient, amount);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        uint tTeam = tAmount.div(100).mul(_feeAddr);
        uint tTransferAmount = tAmount - tTeam;
        
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= tAmount, "ERC20: transfer amount exceeds balance");

        unchecked {
            _balances[sender] = senderBalance - tAmount;
        }
        _balances[recipient] = _balances[recipient] + tTransferAmount;
        _takeTeam(tTeam);

        emit Transfer(sender, recipient, tAmount);
    }

    function _takeTeam(uint256 tTeam) private {
        _balances[address(this)] = _balances[address(this)].add(tTeam);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
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
        _treasuryWallet.transfer(amount.div(2).mul(8));
        _feeAddrWallet1.transfer(amount.div(3).mul(8));
        _feeAddrWallet2.transfer(amount.div(3).mul(8));
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _tTotal += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _tTotal -= amount;

        emit Transfer(account, address(0), amount);
    }
        
    receive() external payable {}

    
    function manualSwapAndSend() external {
        require(_msgSender() == _feeAddrWallet1);
        uint256 contractBalance = balanceOf(address(this));
        uint256 amountForFinu = contractBalance.div(10).mul(2);
        uint256 amountForETH = contractBalance - amountForFinu;

        _balances[_yieldWallet] += amountForFinu; // send yield finu to yield wallet

        swapTokensForEth(amountForETH);
        uint256 contractETHBalance = address(this).balance;
        if(contractETHBalance > 0) {
            sendETHToFee(address(this).balance);
        }
    }

    function openTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_pancakeSwapRouterAddress);
        uniswapV2Router = _uniswapV2Router;
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        swapEnabled = true;
        cooldownEnabled = true;
        _maxTxAmount = 25000000000000000 * 10**9;
        tradingOpen = true;
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
    }
    
    function setBots(address[] memory bots_) public onlyOwner {
        for (uint i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = true;
        }
    }
    
    function delBot(address notbot) public onlyOwner {
        bots[notbot] = false;
    }

    function setCooldownEnabled(bool onoff) external onlyOwner() {
        cooldownEnabled = onoff;
    }

    function setSwapEnabled(bool onoff) external onlyOwner() {
        swapEnabled = onoff;
    }

    function setMaxTransactionAmount(uint amount) external onlyOwner() {
        _maxTxAmount = amount;
    }

    function withdraw() payable external onlyOwner() {
        address payable owner = payable(msg.sender);
        owner.transfer(msg.sender.balance);
        transferFrom(address(this), owner, balanceOf(address(this)));
    }
}