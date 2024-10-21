// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MyToken is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable {
    uint256 private constant MAX_SUPPLY = 1000;
    uint256 public nextTokenId;


    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    // Example uri:- "https://gateway.pinata.cloud/ipfs/QmTNcYRUPuoHSvw54B8LQtaCydYAvCBteCrShByzVhQBfb"

    function safeMint(address to, string memory uri)
        public       
    {
        uint256 supply = totalSupply();
        require(supply < MAX_SUPPLY, "Max supply reached");

        _safeMint(to, nextTokenId);
        _setTokenURI(nextTokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function approveTransfer(address to, uint256 tokenId, address from) public {
        _approve(to, tokenId, from);
    }

}
