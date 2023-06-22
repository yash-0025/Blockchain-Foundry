// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";

contract FundMeTest is Test {
    FundMe  fundMe;

    function setUp() external {
        // Creating new contract
        fundMe = new FundMe();
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.minimumUsd(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        // console.log(fundMe.owner());
        // console.log(msg.sender);
        // assertEq(fundMe.owner(), msg.sender);

        assertEq(fundMe.owner(), address(this));
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }
}
