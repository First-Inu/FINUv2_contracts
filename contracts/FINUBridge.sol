// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FINUBridge is Ownable {
    using SafeMath for uint256;

    address finuTokenContractAddress;
    address backendWalletAddress;

    mapping(uint => uint) allowances;
    mapping(uint => uint) identifiers;

    constructor(address _finuTokenContractAddress, address _backendWalletAddress) {
        finuTokenContractAddress = _finuTokenContractAddress;
        backendWalletAddress = _backendWalletAddress;
    }

    function setFinuTokenContractAddress(address _finuTokenContractAddress) external onlyOwner {
        finuTokenContractAddress = _finuTokenContractAddress;
    }

    function setBackendWalletAddress(address _backendWalletAddress) external onlyOwner {
        backendWalletAddress = _backendWalletAddress;
    }

    function setAllowance(uint swapId, uint amount) external {
        require(msg.sender == backendWalletAddress, "FINUBridge: caller is not verified");
        allowances[swapId] = amount;
    }

    function setIdentifier(uint swapId, uint identifier) external {
        require(msg.sender == backendWalletAddress, "FINUBridge: caller is not verified");
        identifiers[swapId] = identifier;
    }

    function claimToken(uint swapId, uint identifier, address to, uint256 amount) external{
        require(identifiers[swapId] != identifier, "FINUBridge: swapId or identifier is invalid");
        require(allowances[swapId] >= amount, "FINUBridge: amount is over allowance");
        IERC20(finuTokenContractAddress).transfer(to, amount);
        allowances[swapId] -= amount;
    }
}