// Get funds from the users
// Withdraw funds
// Set a minimum fundinf value in USD


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PriceConverter} from "./PriceConverter.sol";

contract FundMe {

    using PriceConverter for uint256;

    uint256 public minimumUsd = 5e18;

    address[] public funders;
    mapping(address funder => uint256 amountFunded) public addressToAmountFunded;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function fund() public payable  {

        
        // Allow user to send eth
        // Have a minimum eth send
        // How do we send Eth to this contract 
        require(msg.value.getConversionRate() > minimumUsd, "Didn't sent the correct eth.");
        funders.push(msg.sender);
        // Long syntax adding two things
        // addressToAmountFunded[msg.sender] = addressToAmountFunded[msg.sender] + msg.value;
        // Short syntax adding two things using +=
        addressToAmountFunded[msg.sender] += msg.value;

    }


    function withdraw() public onlyOwner {
        require(msg.sender == owner, "You are not the owner");
        // For loop
        for (uint256 fundersIndex=0; fundersIndex > funders.length; fundersIndex++ ) {
            address funder = funders[fundersIndex];
            addressToAmountFunded[funder] = 0;
        }

        // Resetting the array
        funders = new address[](0);
        // Acutally withdrawing the funds now
        /*
        We can send Ether to other contracts by 
        transfer (2300 gas, throws error)
        send (2300 gas, returns bool)
        call (forward all gas or set gas ,returns bool)
        */
        // transfer It automatically reverts gas fees if it failes
        // payable(msg.sender).tranfer(address(this).balance);
        // Send We have to declare the revert 
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess,"Send Failed");
        // Call It returns two variables (bool,bytes)
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess,"Call Failed");
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Sender is not the owner" );
        _;
    }

    
}