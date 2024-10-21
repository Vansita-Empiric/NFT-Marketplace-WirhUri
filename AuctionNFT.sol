// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MyToken.sol";
import "hardhat/console.sol";

// Custom errors
error UserRegistered();
error UsernameNotAvailable();

contract AuctionNFT {
    // Custom errors
    error CustomErrorWithReason(string);
    error UserLoggedIn();
    error UserNotLoggedIn();
    error UsernameMismatched();

    // Structure to store user information
    struct User {
        address accountAddress;
        string username;
    }

    // Structure to store auction information
    struct Auction {
        bytes4 auctionId;
        address collectionAdd;
        uint256 tokenId;
        address seller;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
    }

    // mapping to manage users
    mapping(address => User) users;
    mapping(address => bool) isRegistered;
    mapping(string => bool) isUsernameTaken;
    mapping(address => bool) isLoggedIn;

    // mapping to manage auction
    mapping(bytes4 => Auction) auctions;
    mapping(bytes4 => bool) isActive;

    // mapping to get nft owner address
    mapping (MyToken => address[]) mintedNFTs;

    // Structure type array to store all users
    User[] userArr;

    // bytes4 array to store auction ids
    bytes4[] auctionArr;

    // MyToken array to store NFT Collection address
    MyToken[] nftCollectionAddresses;

    modifier isUserLoggedIn() {
        if (isLoggedIn[msg.sender] == false) {
            revert UserNotLoggedIn();
        }
        _;
    }

    // To mint NFT collections
    function mintNFTCollection(string memory name, string memory symbol) isUserLoggedIn external {
        MyToken nftCollectionAddress = new MyToken(name, symbol);
        nftCollectionAddresses.push(nftCollectionAddress);
    }

    // To mint NFT in specified collection
    function mintNFT(MyToken collectionAddress, string memory uri) isUserLoggedIn external {
        collectionAddress.safeMint(msg.sender, uri);
        mintedNFTs[collectionAddress].push(msg.sender);
    }

    // To get all minters of specific NFTCollection's NFT
    function getMinters(MyToken collectionAddress) isUserLoggedIn external view returns (address[] memory) {
        return mintedNFTs[collectionAddress];
    }

    // User registration
    function registerUser(string memory _username) public {
        // Checks if user is already registered
        if (isRegistered[msg.sender] == true) {
            revert UserRegistered();
        }

        // Checks if username is unavailable
        if (isUsernameTaken[_username] == true) {
            revert UsernameNotAvailable();
        }

        User memory userInstance = User(msg.sender, _username);
        users[msg.sender] = userInstance;
        userArr.push(userInstance);

        isRegistered[msg.sender] = true;
        isUsernameTaken[_username] = true;
    }

    // get users
    function getUsers() public view returns (User[] memory) {
        return userArr;
    }

    // User log in
    function logInUser(string memory _username) public {
        // Checks if user is already registered
        if (isRegistered[msg.sender] == false) {
            revert UserRegistered();
        }

        // Checks if user is already loggedIn
        if (isLoggedIn[msg.sender] == true) {
            revert UserLoggedIn();
        }

        // Checks if user is trying to log in with own username
        if (
            keccak256(abi.encodePacked(users[msg.sender].username)) !=
            keccak256(abi.encodePacked(_username))
        ) {
            revert UsernameMismatched();
        }

        isLoggedIn[msg.sender] = true;
    }

    // Logout user
    function logOutUser() public {
        if (isLoggedIn[msg.sender] == true) {
            isLoggedIn[msg.sender] = false;
        } else {
            revert UserNotLoggedIn();
        }
    }

    // putting NFT for sale
    function auctionNFT(
        address _collectionAdd,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _duration
    ) external isUserLoggedIn {
        MyToken nftCollection = MyToken(_collectionAdd);

        // Verify if the user attempting to start the auction is the owner
        if (nftCollection.ownerOf(_tokenId) != msg.sender) {
            revert CustomErrorWithReason("Only the owner can auction the NFT");
        }

        // Verify if the duration is enough
        if (_duration < 0) {
            revert CustomErrorWithReason("Duration must be greater than 0");
        }

        bytes4 aId = bytes4(
            keccak256(abi.encodePacked(block.timestamp, _tokenId))
        );

        Auction memory auctionInstance = Auction(
            aId,
            _collectionAdd,
            _tokenId,
            msg.sender,
            _startingPrice,
            0,
            address(0),
            block.timestamp + _duration
        );
        auctions[aId] = auctionInstance;
        auctionArr.push(aId);

        isActive[aId] = true;
    }

    // Bidding for NFT
    function bid(bytes4 _aId) external payable isUserLoggedIn {
        Auction storage auction = auctions[_aId];

        // Check if the auction is active
        if (!isActive[_aId]) {
            revert CustomErrorWithReason("Auction is not active");
        }

        // Prevent the seller from bidding on their own auction
        if (auction.seller == msg.sender) {
            revert CustomErrorWithReason("You cannot bid on your own auction");
        }

        // Check if the bid is high enough
        if (
            msg.value <= auction.highestBid ||
            msg.value <= auction.startingPrice
        ) {
            revert CustomErrorWithReason("Your bid is not high enough");
        }

        // Refund the previous highest bidder
        if (auction.highestBidder != address(0)) {
            (bool success, ) = payable(auction.highestBidder).call{
                value: auction.highestBid
            }(" ");
            if (!success) {
                revert CustomErrorWithReason("Error while transfering fund");
            }
        }

        // updating with highestBid and highestBidder
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;
    }

    // Ending Auction
    function auctionEnd(bytes4 _aId, MyToken _collectionAdd) external {
        Auction storage auction = auctions[_aId];
        // Check if the auction is active
        if (!isActive[_aId]) {
            revert CustomErrorWithReason("Auction is not active");
        }

        // Approving contract for transfer tokens and bid amount
        _collectionAdd.approveTransfer(address(this), auction.tokenId, auction.seller);

        // Verify if the user attempting to start the auction is the owner
        if (auction.seller != msg.sender) {
            revert CustomErrorWithReason("Only the owner can end auction the NFT");
        }
            
        if (auction.highestBidder == address(0)) {
            revert("No bids have been made");
        }

        // Ensure approval is set before attempting to transfer the token
        if (_collectionAdd.getApproved(auction.tokenId) != address(this)) {
            revert CustomErrorWithReason("Contract not approved to transfer NFT");
        }

        console.log("seller:------------------", auction.seller);
        console.log("highest bidder:------------------", auction.highestBidder);
        console.log("token id:------------------", auction.tokenId);

        // Transfer the token to highest bidder
        _collectionAdd.safeTransferFrom(auction.seller, auction.highestBidder, auction.tokenId);


        // transfer the highest bid amount to seller
        (bool success, ) = payable(auction.seller).call{
            value: auction.highestBid
        }(" ");
        
        if (!success) {
            revert CustomErrorWithReason("Error while transfering fund");
        }

        isActive[_aId] = false;
    }

    // Show auction Ids
    function showAuctions() public view returns (bytes4[] memory) {
        return auctionArr;
    }

    // Show auction detail by Id
    function showAuctionById(bytes4 _aId) public view returns (Auction memory) {
        return auctions[_aId];
    }

    // Show NFTCollection Ids
    function showNFTCollections() public view returns (MyToken[] memory) {
        return nftCollectionAddresses;
    }
}