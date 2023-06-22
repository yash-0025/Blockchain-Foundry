// Deploy mocks when we are on a local anvil chain
// Keeping the track of contract address across different chains

// Sepolia ETH/USD 
// Mainnet ETH/USD

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script{

// If we are on a local anvil, we deploy mocks otherwise grab the existing address from live network
NetworkConfig public activeNetworkConfig;

uint8 public constant DECIMALS = 8;
int256 public constant INITIAL_PRICE = 2000e8;

struct NetworkConfig {
    address priceFeed;
}
constructor() {
    if (block.chainid == 11155111) {
        activeNetworkConfig = getSepolioaEthConfig();
    } else{
        activeNetworkConfig = getOrCreateAnvilConfig();
    }
}

// 1 Deploy mocks when we are on a local chain
function getSepolioaEthConfig() public pure returns(NetworkConfig memory) {
    // price feed address
    NetworkConfig memory sepoliaConfig = NetworkConfig({
        priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
    });
    return sepoliaConfig;
}

function getOrCreateAnvilConfig() public returns
(NetworkConfig memory) {

    if(activeNetworkConfig.priceFeed != address(0)) {
        return activeNetworkConfig;
    }
    // price feed address
    // deploy the mocks
    // Return the mock addresss
    vm.startBroadcast();
    MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
    vm.stopBroadcast();
    
    NetworkConfig memory anvilConfig = NetworkConfig({
        priceFeed: address(mockPriceFeed)
    });
    return anvilConfig;
}

}
