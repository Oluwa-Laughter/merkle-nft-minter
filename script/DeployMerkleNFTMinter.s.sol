// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MerkleNFTMinter} from "../src/MerkleNFTMinter.sol";

contract DeployMerkleNFTMinter is Script {
    function run() external returns (MerkleNFTMinter nft) {
        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");

        vm.startBroadcast();

        nft = new MerkleNFTMinter(
            "Merkle NFT",
            "MNFT",
            0.01 ether,
            100,
            5,
            "ipfs://collection/"
        );

        nft.setMerkleRoot(merkleRoot);

        vm.stopBroadcast();
    }
}
