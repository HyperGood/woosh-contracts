const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('DepositVault', function () {
   let DepositVault, depositVault, owner, addr1, addr2;
   const ZEROADDRESS = '0x0000000000000000000000000000000000000000';

   beforeEach(async function () {
      DepositVault = await ethers.getContractFactory('DepositVault');
      [owner, addr1, addr2, addr3] = await ethers.getSigners();
      depositVault = await DepositVault.deploy('DepositVault', '1.0.0');
   });

   async function createSignature(signer, depositIndex, depositAmount) {
      const message = {
         domain: {
            name: 'DepositVault',
            version: '1.0.0',
            chainId: 31337,
            verifyingContract: depositVault.address,
         },
         value: {
            amount: depositAmount,
            depositIndex: depositIndex,
         },
         types: {
            Withdrawal: [
               { name: 'amount', type: 'uint256' },
               { name: 'depositIndex', type: 'uint256' },
            ],
         },
      };

      const signature = await signer._signTypedData(
         message.domain,
         message.types,
         message.value
      );
      return signature;
   }

   describe('deposit()', function () {
      it('should deposit Ether and emit DepositMade event', async function () {
         const depositAmount = ethers.utils.parseEther('1');

         await expect(
            depositVault.connect(addr1).deposit(0, ZEROADDRESS, {
               value: depositAmount,
            })
         )
            .to.emit(depositVault, 'DepositMade')
            .withArgs(addr1.address, 0, depositAmount, ZEROADDRESS);

         const deposit = await depositVault.deposits(0);
         expect(deposit.depositor).to.equal(addr1.address);
         expect(deposit.balance).to.equal(depositAmount);
      });

      it('should not allow a deposit with zero Ether', async function () {
         await expect(
            depositVault.connect(addr1).deposit(0, ZEROADDRESS, { value: 0 })
         ).to.be.revertedWithCustomError(
            depositVault,
            'DepositVault__DepositAmountMustBeGreaterThanZero'
         );
      });

      it('should desposit an ERC-20 and emit DepositMade event', async function () {
         const depositAmount = ethers.utils.parseUnits('1');
         const ERC20 = await ethers.getContractFactory('MyToken');
         const erc20 = await ERC20.deploy();
         await erc20.transfer(addr1.address, depositAmount);
         await erc20
            .connect(addr1)
            .approve(depositVault.address, depositAmount);

         await expect(
            depositVault.connect(addr1).deposit(depositAmount, erc20.address)
         )
            .to.emit(depositVault, 'DepositMade')
            .withArgs(addr1.address, 0, depositAmount, erc20.address);

         const deposit = await depositVault.deposits(0);
         expect(deposit.depositor).to.equal(addr1.address);
         expect(deposit.balance).to.equal(depositAmount);
      });

      it('should not allow a deposit with zero token amount', async function () {
         const ERC20 = await ethers.getContractFactory('MyToken');
         const erc20 = await ERC20.deploy();
         await expect(
            depositVault.connect(addr1).deposit(0, erc20.address)
         ).to.be.revertedWithCustomError(
            depositVault,
            'DepositVault__DepositAmountMustBeGreaterThanZero'
         );
      });
   });

   describe('withdraw()', function () {
      it('should allow withdrawing Ether with a valid signature', async function () {
         const depositAmount = ethers.utils.parseEther('1');
         await depositVault
            .connect(addr1)
            .deposit(0, ZEROADDRESS, { value: depositAmount });

         const nonce = 0;
         const signature = await createSignature(addr1, nonce, depositAmount);
         const initialRecipientBalance = await addr3.getBalance();
         await expect(
            depositVault
               .connect(addr2)
               .withdraw(nonce, signature, addr3.address)
         )
            .to.emit(depositVault, 'WithdrawalMade')
            .withArgs(addr3.address, depositAmount);

         expect((await depositVault.deposits(0)).balance).to.equal(0);
         expect(initialRecipientBalance.add(depositAmount)).to.equal(
            await addr3.getBalance()
         );
         expect(initialRecipientBalance.add(depositAmount)).to.equal(
            await addr3.getBalance()
         );
      });

      it('should allow withdrawing an ERC-20 with a valid signature', async function () {
         const depositAmount = ethers.utils.parseUnits('1');
         const ERC20 = await ethers.getContractFactory('MyToken');
         const erc20 = await ERC20.deploy();
         await erc20.transfer(addr1.address, depositAmount);
         await erc20
            .connect(addr1)
            .approve(depositVault.address, depositAmount);
         await depositVault
            .connect(addr1)
            .deposit(depositAmount, erc20.address);
         const nonce = 0;
         const signature = await createSignature(addr1, nonce, depositAmount);
         const initialRecipientBalance = await erc20.balanceOf(addr3.address);
         await expect(
            depositVault
               .connect(addr2)
               .withdraw(nonce, signature, addr3.address)
         )
            .to.emit(depositVault, 'WithdrawalMade')
            .withArgs(addr3.address, depositAmount);

         expect((await depositVault.deposits(0)).balance).to.equal(0);
         expect(initialRecipientBalance.add(depositAmount)).to.equal(
            await erc20.balanceOf(addr3.address)
         );
      });

      it('should not allow a withdrawal with an invalid deposit index', async function () {
         const depositAmount = ethers.utils.parseEther('1');
         await depositVault
            .connect(addr1)
            .deposit(0, ZEROADDRESS, { value: depositAmount });
         const nonce = 1; // Invalid deposit index
         const signature = await createSignature(addr1, nonce, depositAmount);
         await expect(
            depositVault
               .connect(addr2)
               .withdraw(nonce, signature, addr2.address)
         ).to.be.revertedWithCustomError(
            depositVault,
            'DepositVault__InvalidDepositIndex'
         );
      });

      it('should not allow a withdrawal with an invalid signature', async function () {
         const depositAmount = ethers.utils.parseEther('1');
         await depositVault
            .connect(addr1)
            .deposit(0, ZEROADDRESS, { value: depositAmount });
         const nonce = 0;

         const signature = await createSignature(addr2, nonce, depositAmount);
         await expect(
            depositVault
               .connect(addr2)
               .withdraw(nonce, signature, addr2.address)
         ).to.be.revertedWithCustomError(
            depositVault,
            'DepositVault__InvalidSignature'
         );
      });

      it('should not allow a withdrawal that has already been executed', async function () {
         const depositAmount = ethers.utils.parseEther('1');
         await depositVault
            .connect(addr1)
            .deposit(0, ZEROADDRESS, { value: depositAmount });
         const nonce = 0;

         const signature = await createSignature(addr1, nonce, depositAmount);
         // Execute the first withdrawal
         await depositVault
            .connect(addr2)
            .withdraw(nonce, signature, addr2.address);

         // Attempt to execute the same withdrawal again
         await expect(
            depositVault
               .connect(addr2)
               .withdraw(nonce, signature, addr2.address)
         ).to.be.revertedWithCustomError(
            depositVault,
            'DepositVault__WithdrawalHasAlreadyBeenExecuted'
         );
      });
   });

   describe('withdrawDeposit()', function () {
      it('should allow the depositor to withdraw their Ether deposit', async function () {
         const depositAmount = ethers.utils.parseEther('1');
         await depositVault
            .connect(addr1)
            .deposit(0, ZEROADDRESS, { value: depositAmount });

         await expect(depositVault.connect(addr1).withdrawDeposit(0))
            .to.emit(depositVault, 'WithdrawalMade')
            .withArgs(addr1.address, depositAmount);

         expect((await depositVault.deposits(0)).balance).to.equal(0);
      });

      it('should allow the depositor to withdraw their ERC-20 deposit', async function () {
         const depositAmount = ethers.utils.parseUnits('1');
         const ERC20 = await ethers.getContractFactory('MyToken');
         const erc20 = await ERC20.deploy();
         await erc20.transfer(addr1.address, depositAmount);
         await erc20
            .connect(addr1)
            .approve(depositVault.address, depositAmount);
         await depositVault
            .connect(addr1)
            .deposit(depositAmount, erc20.address);

         await expect(depositVault.connect(addr1).withdrawDeposit(0))
            .to.emit(depositVault, 'WithdrawalMade')
            .withArgs(addr1.address, depositAmount);

         expect((await depositVault.deposits(0)).balance).to.equal(0);
      });

      it('should not allow to withdraw the deposit to someone different from the depositor', async function () {
         const depositAmount = ethers.utils.parseEther('1');
         await depositVault
            .connect(addr1)
            .deposit(0, ZEROADDRESS, { value: depositAmount });

         await expect(
            depositVault.connect(addr2).withdrawDeposit(0)
         ).to.be.revertedWithCustomError(
            depositVault,
            'DepositVault__OnlyDepositor'
         );

         expect((await depositVault.deposits(0)).balance).to.equal(
            depositAmount
         );
      });
   });
});
