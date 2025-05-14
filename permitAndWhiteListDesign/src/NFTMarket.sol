// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract NFTMarket is IERC721Receiver, EIP712 {
    using ECDSA for bytes32;

    struct Listing {
        address seller;
        uint256 price;
    }

    IERC20 public immutable paymentToken;
    address public immutable signer;
    mapping(address => mapping(uint256 => Listing)) public listings; // nftContract => tokenId => Listing
    mapping(bytes32 => bool) public usedSignatures;
    mapping(address => uint256) public nonces;

    bytes32 public constant _PERMIT_TYPEHASH =
        keccak256("PermitBuy(address buyer,address nftContract,uint256 tokenId,uint256 nonce)");

    event Listed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event Sold(address indexed buyer, address indexed nftContract, uint256 indexed tokenId, uint256 price);

    constructor(address _paymentToken, address _signer) EIP712("NFTMarket", "1") {
        paymentToken = IERC20(_paymentToken);
        signer = _signer;
    }

    function list(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "Not the owner"
        );
        require(
            IERC721(nftContract).getApproved(tokenId) == address(this) ||
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)),
            "NFT not approved"
        );

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price
        });

        emit Listed(msg.sender, nftContract, tokenId, price);
    }

    function buyNFT(address nftContract, uint256 tokenId) external {
        _buyNFT(nftContract, tokenId);
    }

    function permitBuy(
        address nftContract,
        uint256 tokenId,
        uint256 nonce,
        bytes memory signature
    ) external {
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(
                _PERMIT_TYPEHASH,
                msg.sender,
                nftContract,
                tokenId,
                nonce
            ))
        );
        require(!usedSignatures[digest], "Signature already used");
        require(ECDSA.recover(digest, signature) == signer, "Invalid signature");
        require(nonces[msg.sender] == nonce, "Invalid nonce");

        usedSignatures[digest] = true;
        nonces[msg.sender]++;
        _buyNFT(nftContract, tokenId);
    }

    function _buyNFT(address nftContract, uint256 tokenId) private {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.seller != address(0), "NFT not listed");

        // Transfer payment
        paymentToken.transferFrom(msg.sender, listing.seller, listing.price);

        // Transfer NFT
        IERC721(nftContract).safeTransferFrom(listing.seller, msg.sender, tokenId);

        // Remove listing
        delete listings[nftContract][tokenId];

        emit Sold(msg.sender, nftContract, tokenId, listing.price);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
