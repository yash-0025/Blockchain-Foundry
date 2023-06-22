// Get funds from the users
// Withdraw funds
// Set a minimum fundinf value in USD


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PriceConverter} from "./PriceConverter.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FundMe {

    using PriceConverter for uint256;

    uint256 public minimumUsd = 5e18;

    address[] private s_funders;
    mapping(address funder => uint256 amountFunded) private s_addressToAmountFunded;

    address private immutable owner;
    AggregatorV3Interface private s_priceFeed;


    constructor(address priceFeed) {
        owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable  {

        
        // Allow user to send eth
        // Have a minimum eth send
        // How do we send Eth to this contract 
        require(msg.value.getConversionRate(s_priceFeed) > minimumUsd, "Didn't sent the correct eth.");
        s_funders.push(msg.sender);
        // Long syntax adding two things
        // addressToAmountFunded[msg.sender] = addressToAmountFunded[msg.sender] + msg.value;
        // Short syntax adding two things using +=
        s_addressToAmountFunded[msg.sender] += msg.value;

    }


    function withdraw() public onlyOwner {
        require(msg.sender == owner, "You are not the owner");
        // For loop
        for (uint256 fundersIndex=0; fundersIndex > s_funders.length; fundersIndex++ ) {
            address funder = s_funders[fundersIndex];
            s_addressToAmountFunded[funder] = 0;
        }

        // Resetting the array
        s_funders = new address[](0);
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

    function getVersion() public view returns (uint256) {
        // AggregatorV3Interface priceFeed =  AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        // return priceFeed.version();
        return s_priceFeed.version();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Sender is not the owner" );
        _;
    }

    function getAddressToAmountFunded(address fundingAddress) external view returns(uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns(address) {
        return s_funders[index];
    }
    
    function getOwner() external view returns(address) {
        return owner;
    }
}