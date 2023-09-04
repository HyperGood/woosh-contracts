// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error DepositVault__DepositAmountMustBeGreaterThanZero();
error DepositVault__IsZeroAddress();
error DepositVault__IsNotZeroAddress();
error DepositVault__InvalidDepositIndex();
error DepositVault__WithdrawalHasAlreadyBeenExecuted();
error DepositVault__InvalidSignature();
error DepositVault__TransferFailed();
error DepositVault__OnlyDepositor();

///@title Woosh DepositVault Contract
///@author @Temo_RH https://github.com/ktemo
///@notice This contract allows users to deposit ETH or ERC20 tokens and withdraw them using a signature

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
        uint256 depositIndex;
    }

    Deposit[] public deposits;

    mapping(bytes32 => bool) public usedWithdrawalHashes;
    bytes32 private constant WITHDRAWAL_TYPEHASH =
        keccak256("Withdrawal(uint256 amount,uint256 depositIndex)");

    event DepositMade(
        address indexed depositor,
        uint256 indexed depositIndex,
        uint256 balance,
        address tokenAddress
    );
    event WithdrawalMade(address indexed recipient, uint256 amount);

    constructor(
        string memory domainName,
        string memory domainVersion
    ) EIP712(domainName, domainVersion) {}

    function deposit(uint256 amount, address tokenAddress) external payable {
        if (amount == 0 && msg.value == 0)
            revert DepositVault__DepositAmountMustBeGreaterThanZero();

        if (msg.value != 0) {
            if (!isAddressZero(tokenAddress))
                revert DepositVault__IsNotZeroAddress();
            uint256 depositIndex = deposits.length;
            deposits.push(
                Deposit(payable(msg.sender), tokenAddress, msg.value)
            );
            emit DepositMade(msg.sender, depositIndex, msg.value, tokenAddress);
        } else {
            if (isAddressZero(tokenAddress))
                revert DepositVault__IsZeroAddress();
            uint256 depositIndex = deposits.length;
            (bool success, uint256 balance) = depositTokens(
                amount,
                tokenAddress
            );
            if (!success) revert DepositVault__TransferFailed();
            deposits.push(Deposit(payable(msg.sender), tokenAddress, balance));
            emit DepositMade(msg.sender, depositIndex, balance, tokenAddress);
        }
    }

    function withdraw(
        uint256 depositIndex,
        bytes calldata signature,
        address payable recipient
    ) external {
        if (depositIndex >= deposits.length)
            revert DepositVault__InvalidDepositIndex();
        Deposit storage depositToWithdraw = deposits[depositIndex];
        if (depositToWithdraw.balance == 0)
            revert DepositVault__WithdrawalHasAlreadyBeenExecuted();
        bytes32 withdrawalHash = getWithdrawalHash(
            Withdrawal(depositToWithdraw.balance, depositIndex)
        );
        address signer = withdrawalHash.recover(signature);
        if (signer != depositToWithdraw.depositor)
            revert DepositVault__InvalidSignature();
        if (usedWithdrawalHashes[withdrawalHash])
            revert DepositVault__WithdrawalHasAlreadyBeenExecuted();

        uint256 amount = depositToWithdraw.balance;
        usedWithdrawalHashes[withdrawalHash] = true;
        depositToWithdraw.balance = 0;

        if (isAddressZero(depositToWithdraw.tokenAddress)) {
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) revert DepositVault__TransferFailed();
        } else {
            IERC20 token = IERC20(depositToWithdraw.tokenAddress);
            token.safeTransfer(recipient, amount);
        }

        emit WithdrawalMade(recipient, amount);
    }

    function withdrawDeposit(uint256 depositIndex) external {
        if (depositIndex >= deposits.length)
            revert DepositVault__InvalidDepositIndex();
        Deposit storage depositToWithdraw = deposits[depositIndex];
        if (depositToWithdraw.depositor != msg.sender)
            revert DepositVault__OnlyDepositor();
        if (depositToWithdraw.balance == 0)
            revert DepositVault__WithdrawalHasAlreadyBeenExecuted();

        uint256 amount = depositToWithdraw.balance;
        depositToWithdraw.balance = 0;

        if (isAddressZero(depositToWithdraw.tokenAddress)) {
            (bool success, ) = depositToWithdraw.depositor.call{value: amount}(
                ""
            );
            if (!success) revert DepositVault__TransferFailed();
        } else {
            IERC20 token = IERC20(depositToWithdraw.tokenAddress);
            token.safeTransfer(depositToWithdraw.depositor, amount);
        }

        emit WithdrawalMade(depositToWithdraw.depositor, amount);
    }

    function getWithdrawalHash(
        Withdrawal memory withdrawal
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        WITHDRAWAL_TYPEHASH,
                        withdrawal.amount,
                        withdrawal.depositIndex
                    )
                )
            );
    }

    function depositTokens(
        uint256 amount,
        address tokenAddress
    ) internal returns (bool success, uint256 balance) {
        IERC20 token = IERC20(tokenAddress);
        uint256 initialBalance = token.balanceOf(address(this));
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );
        uint256 depositedAmount = token.balanceOf(address(this)) -
            initialBalance;
        return (true, depositedAmount);
    }

    function isAddressZero(address _addr) internal pure returns (bool) {
        bool isZero;
        assembly {
            mstore(0, 0x00)
            isZero := eq(_addr, mload(0))
        }
        return isZero;
    }
}
