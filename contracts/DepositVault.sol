// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

///@title Woosh DepositVault Contract
///@author @Temo_RH https://github.com/ktemo

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';


error DepositAmountMustBeGreaterThanZero();
error IsZeroAddress();
error IsNotZeroAddress();
error InvalidDepositIndex();
error WithdrawalHasAlreadyBeenExecuted();
error InvalidSignature();
error TokenTransferFailed();
error EtherTransferFailed();
error OnlyDepositor();

contract DepositVault is EIP712 {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    struct Deposit {
        address payable depositor;
        address tokenAddress;
        uint256 balance;
    }

    struct Withdrawal {
        uint256 amount;
        uint256 nonce;
    }

    Deposit[] public deposits;

    mapping(bytes32 => bool) public usedWithdrawalHashes;
    bytes32 private constant WITHDRAWAL_TYPEHASH = keccak256("Withdrawal(uint256 amount,uint256 nonce)");

    event DepositMade(address indexed depositor, uint256 indexed depositIndex, uint256 balance, address tokenAddress);
    event WithdrawalMade(address indexed recipient, uint256 amount);

    constructor(string memory domainName, string memory domainVersion) EIP712(domainName, domainVersion) {}

    function isAddressZero(address _addr) internal pure returns (bool) {
        bool isZero;
        assembly {
            mstore(0, 0x00)
            isZero := eq(_addr, mload(0))
        }
        return isZero;
    }

    function deposit(uint256 amount, address tokenAddress) external payable {
        // require(amount !=  0 || msg.value != 0, "Deposit amount must be greater than 0");
        if(amount ==  0 && msg.value == 0) revert DepositAmountMustBeGreaterThanZero();

        if(msg.value != 0) {
            if(!isAddressZero(tokenAddress)) revert IsNotZeroAddress();
            uint256 depositIndex = deposits.length;
            deposits.push(Deposit(payable(msg.sender), tokenAddress, msg.value));
            emit DepositMade(msg.sender, depositIndex, msg.value, tokenAddress);
        } else {
            if(isAddressZero(tokenAddress)) revert IsZeroAddress();
            uint256 depositIndex = deposits.length;
            (bool success, uint256 balance) = depositTokens(amount, tokenAddress);
            if(!success) revert TokenTransferFailed();
            deposits.push(Deposit(payable(msg.sender), tokenAddress, balance));
            emit DepositMade(msg.sender, depositIndex, balance, tokenAddress);
        }
    }   

    function depositTokens(uint256 amount, address tokenAddress) internal returns (bool success, uint256 balance){
        if(amount ==  0) revert DepositAmountMustBeGreaterThanZero();
        if(isAddressZero(tokenAddress)) revert IsZeroAddress();
        IERC20 token = IERC20(tokenAddress);
        uint256 initialBalance = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        uint256 depositedAmount = token.balanceOf(address(this)) - initialBalance;
        return (true, depositedAmount);
    }

    function getWithdrawalHash(Withdrawal memory withdrawal) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(WITHDRAWAL_TYPEHASH, withdrawal.amount, withdrawal.nonce)));
    }

    function withdraw(uint256 depositIndex, bytes calldata signature, address payable recipient) external {
        if(depositIndex >= deposits.length) revert InvalidDepositIndex();
        Deposit storage depositToWithdraw = deposits[depositIndex];
        if(depositToWithdraw.balance == 0) revert WithdrawalHasAlreadyBeenExecuted();
        bytes32 withdrawalHash = getWithdrawalHash(Withdrawal(depositToWithdraw.balance, depositIndex));
        address signer = withdrawalHash.recover(signature);
        if(signer != depositToWithdraw.depositor) revert InvalidSignature();
        if(usedWithdrawalHashes[withdrawalHash]) revert WithdrawalHasAlreadyBeenExecuted();
      
        uint256 amount = depositToWithdraw.balance;
        usedWithdrawalHashes[withdrawalHash] = true;
        depositToWithdraw.balance = 0;

        if(isAddressZero(depositToWithdraw.tokenAddress)){
            (bool success, ) = recipient.call{value: amount}("");
            if(!success) revert EtherTransferFailed();
        } else {
            IERC20 token = IERC20(depositToWithdraw.tokenAddress);
            token.safeTransfer(recipient, amount);
        }

        emit WithdrawalMade(recipient, amount);
    }

    function withdrawDeposit(uint256 depositIndex) external {
        if(depositIndex > deposits.length) revert InvalidDepositIndex();
        Deposit storage depositToWithdraw = deposits[depositIndex];
        if(depositToWithdraw.depositor != msg.sender) revert OnlyDepositor();
        if(depositToWithdraw.balance == 0) revert WithdrawalHasAlreadyBeenExecuted();


        uint256 amount = depositToWithdraw.balance;
        depositToWithdraw.balance = 0;

        if(isAddressZero(depositToWithdraw.tokenAddress)){
            (bool success, ) = depositToWithdraw.depositor.call{value: amount}("");
            if(!success) revert EtherTransferFailed();
        } else {
            IERC20 token = IERC20(depositToWithdraw.tokenAddress);
            token.safeTransfer(depositToWithdraw.depositor, amount);
        }

        emit WithdrawalMade(depositToWithdraw.depositor, amount);
    }
}