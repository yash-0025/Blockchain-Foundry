// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe  fundMe;

    // Creating a fake user for transactions testing using forge std
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // Creating new contract
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.minimumUsd(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        // console.log(fundMe.owner());
        // console.log(msg.sender);
        assertEq(fundMe.getOwner(), msg.sender);

        // assertEq(fundMe.owner(), address(this));
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // the next should revert 
        fundMe.fund(); // Sending 0 value
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }
modifier funded() {
    vm.prank(USER);
    fundMe.fund{value: SEND_VALUE}();
    _;
}

    function testOnlyOwnerCanWithdraw() public funded {
        /* 
// Instead of using this everytime we will use a modifier for it
        // vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();
 */
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }


    function testWithDrawaWithASingleFunder() public funded {
        // WE plan test in three parts 

        // ARRANGE ->To plan the test 
        uint256 startingOwnerBalance = fundMe.getOwner().balance; // Checking owner balance before withdrawing
        uint256 startingFundMeBalance = address(fundMe).balance; // Checking the contract balance before withdrawing


        // ACT -> What acitons we are going to make
        uint256 gasStart = gasleft(); // It is a buit in function in solidity so we will check the before and after transaction gas
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 gasEnd = gasleft(); //AFter transaction the amount of gas left
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; // tx.gasprice is a builtin solidity which tells us the current gas price
        console.log(gasUsed);

        // ASSERT -> we will check the assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        // So now the contract balance will be zero so will assert 
        assertEq(endingFundMeBalance,0);
        // The ending balance of the owner should be starting balance of his account + contract balance 
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);

    }

    function testWithDrawaWithAMultipleFunder() public funded {

        // so here we will use hoax which is a combination of vm.prank and vm.deal to create a demo funder and funding it 
        // Arrange
        // So after upgrades in solidity we have to use uint160 for addresses 
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        // Now we will loop through all the users to create their accounts to fund the contract 
        for ( uint160 i = startingFunderIndex; i < numberOfFunders ; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // ACT
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //ASSERT
        
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);


    }

    function testWithDrawaWithAMultipleFunderCheaper() public funded {

        // so here we will use hoax which is a combination of vm.prank and vm.deal to create a demo funder and funding it 
        // Arrange
        // So after upgrades in solidity we have to use uint160 for addresses 
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        // Now we will loop through all the users to create their accounts to fund the contract 
        for ( uint160 i = startingFunderIndex; i < numberOfFunders ; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // ACT
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        //ASSERT
        
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);


    }

}
