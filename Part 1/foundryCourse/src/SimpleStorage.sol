// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SimpleStorage {
    uint256 public myFavourtieNumber;
    // uint256[] listOfFavouriteNumber;

    struct Person {
        uint256 favouriteNumber;
        string name;
    }

    // Person public yas = Person({favouriteNumber:7, name:"Yas"});
    Person[] public listOfPeople; //dynamic array no size mentioned

    mapping(string => uint256) public nameToFavouriteNumber;

    function store(uint256 _favouriteNumber) public virtual {
        myFavourtieNumber = _favouriteNumber;
    }

    function retrieve() public view returns (uint256) {
        return myFavourtieNumber;
    }

    function addPerson(string memory _name, uint256 _favouriteNumber) public {
        listOfPeople.push(Person(_favouriteNumber, _name));
        nameToFavouriteNumber[_name] = _favouriteNumber;
    }
}
