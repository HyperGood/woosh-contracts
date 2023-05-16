// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract DepositVault is EIP712 {
    using ECDSA for bytes32;

    struct Deposit {
        address payable depositor;
        uint256 amount;
    }

    struct Withdrawal {
        uint256 amount;
        uint256 nonce;
    }

    Deposit[] public deposits;

    mapping(bytes32 => bool) public usedWithdrawalHashes;
    bytes32 private constant WITHDRAWAL_TYPEHASH = keccak256("Withdrawal(uint256 amount,uint256 nonce)");

    event DepositMade(address indexed depositor, uint256 indexed depositIndex, uint256 amount);
    event WithdrawalMade(address indexed recipient, uint256 amount);

    constructor(string memory domainName, string memory domainVersion) EIP712(domainName, domainVersion) {}

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        uint256 depositIndex = deposits.length;
        deposits.push(Deposit(payable(msg.sender), msg.value));
        emit DepositMade(msg.sender, depositIndex, msg.value);
    }

    function getWithdrawalHash(Withdrawal memory withdrawal) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(WITHDRAWAL_TYPEHASH, withdrawal.amount, withdrawal.nonce)));
    }

    function withdraw(uint256 amount, uint256 nonce, bytes memory signature, address payable recipient) public {
        require(nonce < deposits.length, "Invalid deposit index");
        Deposit storage depositToWithdraw = deposits[nonce];
        bytes32 withdrawalHash = getWithdrawalHash(Withdrawal(amount, nonce));
        address signer = withdrawalHash.recover(signature);
        require(signer == depositToWithdraw.depositor, "Invalid signature");
        require(!usedWithdrawalHashes[withdrawalHash], "Withdrawal has already been executed");
        require(amount == depositToWithdraw.amount, "Withdrawal amount must match deposit amount");

        usedWithdrawalHashes[withdrawalHash] = true;
        depositToWithdraw.amount = 0;
        recipient.transfer(amount);

        emit WithdrawalMade(recipient, amount);
    }

    function withdrawDeposit(uint256 depositIndex) public {
        require(depositIndex < deposits.length, "Invalid deposit index");
        Deposit storage depositToWithdraw = deposits[depositIndex];
        require(depositToWithdraw.depositor == msg.sender, "Only the depositor can withdraw their deposit");
        require(depositToWithdraw.amount > 0, "Deposit has already been withdrawn");

        uint256 amount = depositToWithdraw.amount;
        depositToWithdraw.amount = 0;
        depositToWithdraw.depositor.transfer(amount);

        emit WithdrawalMade(depositToWithdraw.depositor, amount);
    }

    function getDeposits() public view returns(Deposit[] memory){
        return deposits;
    }
}