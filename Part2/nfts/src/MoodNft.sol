// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract MoodNft is ERC721 {

    // errors 
    error MoodNft_CantFlipMoodIfNotOwner();

    uint256 private s_tokenCounter;
    string private s_sadSvgImageUri;
    string private s_happySvgImageUri;

    enum Mood {
        HAPPY,
        SAD
    }

    mapping(uint256 => Mood) private s_tokenIdMood;

    constructor(
        string memory sadSvgImageUri,
        string memory happySvgImageUri
    ) ERC721("Mood NFT", "MN") {
        s_tokenCounter = 0;
        s_sadSvgImageUri = sadSvgImageUri;
        s_happySvgImageUri = happySvgImageUri;
    }

    // Mint te nft
    function mintNft() public {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdMood[s_tokenCounter] = Mood.HAPPY;
        s_tokenCounter++;
    }

    function flipMood(uint256 tokenId ) public {
        // only want the owner of the nft to change the mood 
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert MoodNft_CantFlipMoodIfNotOwner();
        }
        if(s_tokenIdMood[tokenId] == Mood.HAPPY) {
            s_tokenIdMood[tokenId] = Mood.SAD;
        } else {
            s_tokenIdMood[tokenId] = Mood.HAPPY;
        }

    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        string memory imageURI;
        if (s_tokenIdMood[tokenId] == Mood.HAPPY) {
            imageURI = s_happySvgImageUri;
        } else {
            imageURI = s_sadSvgImageUri;
        }

        // WE cannot use concat as we need it in bytes to send it onchain
        /*  string memory tokenMetadata = string.concat(
            '{"name": "',
            name(),
            '", "description": "An Nft reflects the owners mood","attributes" : [{"trait_type": "moodiness", "value":100}], "image": "',
            imageURI,
            '"}'
        ); */
        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name": "',
                                name(),
                                '", "description": "An Nft reflects the owners mood","attributes" : [{"trait_type": "moodiness", "value":100}], "image": "',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}
