// SPDX-License-Identifier:MIT


pragma solidity ^0.8.19;

import "./SimpleStorage.sol";

contract StorageFactory{

    SimpleStorage[] public listOfSimpleStorageContract;

    function createSimpleStorageContract() public {
        SimpleStorage newSimpleStorageContract = new SimpleStorage();
        listOfSimpleStorageContract.push(newSimpleStorageContract);
    }

    function sfStore(uint256 _simpleStorageIndex, uint256 _newSimpleStorageNumber) public {
        // Complex or long syntax
        // SimpleStorage mySimpleStorage = listOfSimpleStorageContract[_simpleStorageIndex];
        // mySimpleStorage.store(_newSimpleStorageNumber); // here we call .store function from the SimpleStorage contract

        // Simpler Syntax and short 
        listOfSimpleStorageContract[_simpleStorageIndex].store(_newSimpleStorageNumber);
    }

    function sfGet(uint256 _simpleStorageIndex) public view returns(uint256) {
        // More Syntax format 
        // SimpleStorage mySimpleStorage = listOfSimpleStorageContract[_simpleStorageIndex];
        // return mySimpleStorage.retrieve(); // Here we call .retrieve function from the Simple Storage contract.
        //Simple way  Less syntax
        return listOfSimpleStorageContract[_simpleStorageIndex].retrieve();
    }
}