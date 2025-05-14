// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BinToken.sol";
import "../src/NFTMarket.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {
    constructor() ERC721("TestNFT", "TNFT") {}
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract NFTMarketTest is Test {
    BinToken public token;
    TestNFT public nft;
    NFTMarket public market;
    address public signer = address(0x9ED76373624C3A1ca589D3D012E0B822a1fA0407); // 对应vm.sign(1)的地址
    address public userA = address(0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf); // 使用与签名相同的地址
    address public userB = address(0x2);

    function setUp() public {
        token = new BinToken();
        nft = new TestNFT();
        market = new NFTMarket(address(token), signer);

        // Distribute initial tokens
        token.transfer(userA, 100 ether);
        token.transfer(userB, 100 ether);

        // Mint test NFT to userB
        nft.mint(userB, 1);
    }

    function testDepositAndBuyNFT() public {
        // UserB lists NFT for sale
        vm.startPrank(userB);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, 10 ether);
        vm.stopPrank();

        // UserA approves market to spend tokens
        vm.startPrank(userA);
        token.approve(address(market), 10 ether);
        
        // Check initial balances
        assertEq(token.balanceOf(userA), 100 ether);
        assertEq(token.balanceOf(userB), 100 ether);
        assertEq(nft.ownerOf(1), userB);

        // UserA buys NFT
        market.buyNFT(address(nft), 1);

        // Check balances after purchase
        assertEq(token.balanceOf(userA), 90 ether); // -10 ether
        assertEq(token.balanceOf(userB), 110 ether); // +10 ether
        assertEq(nft.ownerOf(1), userA); // NFT transferred
        vm.stopPrank();
    }

    function testPermitBuy() public {
        // UserB lists NFT for sale
        vm.startPrank(userB);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, 10 ether);
        vm.stopPrank();

        // UserA approves market to spend tokens
        vm.startPrank(userA);
        token.approve(address(market), 10 ether);

        // Check initial balances
        assertEq(token.balanceOf(userA), 100 ether);
        assertEq(token.balanceOf(userB), 100 ether);
        assertEq(nft.ownerOf(1), userB);

        // Reconstruct EIP712 digest manually
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version)"),
            keccak256("NFTMarket"),
            keccak256("1")
        ));
        
        // 获取当前有效的nonce值
        uint256 currentNonce = market.nonces(userA);
        
        bytes32 structHash = keccak256(abi.encode(
            keccak256("PermitBuy(address buyer,address nftContract,uint256 tokenId,uint256 nonce)"), 
            userA,
            address(nft),
            1,
            currentNonce
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);

        // UserA buys with permit
        market.permitBuy(address(nft), 1, currentNonce, abi.encodePacked(r, s, v));

        // Check balances after purchase
        assertEq(token.balanceOf(userA), 90 ether); // -10 ether
        assertEq(token.balanceOf(userB), 110 ether); // +10 ether
        assertEq(nft.ownerOf(1), userA); // NFT transferred
        vm.stopPrank();
    }
}
