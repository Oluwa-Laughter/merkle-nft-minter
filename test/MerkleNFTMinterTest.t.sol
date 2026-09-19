// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MerkleNFTMinter} from "../src/MerkleNFTMinter.sol";

contract MerkleNFTMinterTest is Test {
    MerkleNFTMinter nft;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant PRICE = 0.01 ether;
    uint256 constant MAX_SUPPLY = 5;
    uint256 constant PUBLIC_WALLET_LIMIT = 5;

    bytes32 aliceLeaf;
    bytes32 bobLeaf;
    bytes32 merkleRoot;

    function setUp() public {
        aliceLeaf = _leaf(alice, 3);

        bobLeaf = _leaf(bob, 2);

        merkleRoot = _hashPair(aliceLeaf, bobLeaf);

        vm.prank(owner);

        nft = new MerkleNFTMinter("Merkle NFT", "MNFT", PRICE, MAX_SUPPLY, PUBLIC_WALLET_LIMIT, "ipfs://collection/");

        vm.prank(owner);

        nft.setMerkleRoot(merkleRoot);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testValidProof() public {
        _setPhase(MerkleNFTMinter.Phase.Allowlist);

        vm.prank(alice);

        nft.allowlistMint{value: PRICE}(1, 3, _aliceProof());

        assertEq(nft.balanceOf(alice), 1);

        assertEq(nft.allowlistMinted(alice), 1);
    }

    function testInvalidProof() public {
        _setPhase(MerkleNFTMinter.Phase.Allowlist);

        vm.prank(bob);

        vm.expectRevert(MerkleNFTMinter.InvalidProof.selector);

        nft.allowlistMint{value: PRICE}(1, 3, _aliceProof());
    }

    function testAlteredAllowanceInvalidatesProof() public {
        _setPhase(MerkleNFTMinter.Phase.Allowlist);

        vm.prank(alice);

        vm.expectRevert(MerkleNFTMinter.InvalidProof.selector);

        nft.allowlistMint{value: PRICE}(1, 10, _aliceProof());
    }

    function testCannotExceedAllowlistClaim() public {
        _setPhase(MerkleNFTMinter.Phase.Allowlist);

        bytes32[] memory proof = _aliceProof();

        vm.startPrank(alice);

        nft.allowlistMint{value: PRICE * 2}(2, 3, proof);

        nft.allowlistMint{value: PRICE}(1, 3, proof);

        vm.expectRevert(MerkleNFTMinter.AllowanceExceeded.selector);

        nft.allowlistMint{value: PRICE}(1, 3, proof);

        vm.stopPrank();

        assertEq(nft.allowlistMinted(alice), 3);
    }

    function testSupplyExhaustion() public {
        _setPhase(MerkleNFTMinter.Phase.Public);

        vm.prank(alice);

        nft.publicMint{value: PRICE * 5}(5);

        assertEq(nft.totalSupply(), MAX_SUPPLY);

        vm.prank(bob);

        vm.expectRevert(MerkleNFTMinter.MaxSupplyExceeded.selector);

        nft.publicMint{value: PRICE}(1);
    }

    function testExactPaymentWorks() public {
        _setPhase(MerkleNFTMinter.Phase.Public);

        vm.prank(alice);

        nft.publicMint{value: PRICE * 2}(2);

        assertEq(nft.balanceOf(alice), 2);

        assertEq(address(nft).balance, PRICE * 2);
    }

    function testUnderpaymentReverts() public {
        _setPhase(MerkleNFTMinter.Phase.Public);

        vm.prank(alice);

        vm.expectRevert(MerkleNFTMinter.IncorrectPayment.selector);

        nft.publicMint{value: PRICE - 1}(1);
    }

    function testOverpaymentReverts() public {
        _setPhase(MerkleNFTMinter.Phase.Public);

        vm.prank(alice);

        vm.expectRevert(MerkleNFTMinter.IncorrectPayment.selector);

        nft.publicMint{value: PRICE + 1}(1);
    }

    function testInitialPhaseIsInactive() public view {
        assertEq(uint256(nft.phase()), uint256(MerkleNFTMinter.Phase.Inactive));
    }

    function testAllowlistMintFailsWhenInactive() public {
        vm.prank(alice);

        vm.expectRevert(MerkleNFTMinter.WrongPhase.selector);

        nft.allowlistMint{value: PRICE}(1, 3, _aliceProof());
    }

    function testAllowlistPhaseOnlyAllowsAllowlistMint() public {
        _setPhase(MerkleNFTMinter.Phase.Allowlist);

        vm.prank(alice);

        nft.allowlistMint{value: PRICE}(1, 3, _aliceProof());

        vm.prank(bob);

        vm.expectRevert(MerkleNFTMinter.WrongPhase.selector);

        nft.publicMint{value: PRICE}(1);
    }

    function testPublicPhaseOnlyAllowsPublicMint() public {
        _setPhase(MerkleNFTMinter.Phase.Public);

        vm.prank(bob);

        nft.publicMint{value: PRICE}(1);

        vm.prank(alice);

        vm.expectRevert(MerkleNFTMinter.WrongPhase.selector);

        nft.allowlistMint{value: PRICE}(1, 3, _aliceProof());
    }

    function testPhaseTransitions() public {
        assertEq(uint256(nft.phase()), uint256(MerkleNFTMinter.Phase.Inactive));

        _setPhase(MerkleNFTMinter.Phase.Allowlist);

        assertEq(uint256(nft.phase()), uint256(MerkleNFTMinter.Phase.Allowlist));

        _setPhase(MerkleNFTMinter.Phase.Public);

        assertEq(uint256(nft.phase()), uint256(MerkleNFTMinter.Phase.Public));
    }

    function _setPhase(MerkleNFTMinter.Phase newPhase) internal {
        vm.prank(owner);

        nft.setPhase(newPhase);
    }

    function _leaf(address account, uint256 allowance) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, allowance));
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        if (a < b) {
            return keccak256(abi.encodePacked(a, b));
        }

        return keccak256(abi.encodePacked(b, a));
    }

    function _aliceProof() internal view returns (bytes32[] memory proof) {
        proof = new bytes32[](1);

        proof[0] = bobLeaf;
    }
}
