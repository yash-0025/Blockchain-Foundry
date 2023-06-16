// Library :- It is very similar to contracts but we can't declare any state variable and can't send ether
// library is embedded into the contract if all library function are internal
// Library must be deployed and then linked before the contract is deployed

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice() internal view returns(uint256) {
        // We are calling this function from the other smart contract so we will need
        // Address 0x694AA1769357215DE4FAC081bf1f309aDC325306
        // ABI of the smart Contract 
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price * 1e10); // Conversion takes place.
    }

    function getConversionRate(uint256 ethAmount) internal view returns(uint256) {
        uint256 ethPrice = getPrice();
        // Here the eth price and eth amount will be 10 to power 18 for both so it will become 10 to power 36 thats why we are dividing it with 10 to power 18 so here the math will be 
        // 10 ** 18 * 10 ** 18 / 10 ** 18 // This is how it will work.
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18 ;
        return ethAmountInUsd;
    }

    function getVersion() internal view returns(uint256) {
        return AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306).version();
    }
}