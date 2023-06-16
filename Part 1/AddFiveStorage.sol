// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
// It is a child contract of storage contract";


import {SimpleStorage} from "./SimpleStorage.sol";

contract AddFiveStorage is SimpleStorage {
    function sayHello() public pure returns(string memory) {
        return "Hello";
    }

    function store(uint256 _newNumber) public override {
        myFavourtieNumber = _newNumber + 5 ;
    }
}
