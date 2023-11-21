// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { IPufferStrategy } from "puffer/interface/IPufferStrategy.sol";
import { NoRestakingStrategy } from "puffer/NoRestakingStrategy.sol";
import { Safe } from "safe-contracts/Safe.sol";
import { ECDSA } from "openzeppelin/utils/cryptography/ECDSA.sol";
import { TestHelper } from "../helpers/TestHelper.sol";
import { PufferProtocol } from "puffer/PufferProtocol.sol";

contract NoRestakingStartegyTest is TestHelper {
    using ECDSA for bytes32;

    NoRestakingStrategy strategy;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    function setUp() public override {
        // Just call the parent setUp()
        super.setUp();
        _skipDefaultFuzzAddresses();

        strategy = NoRestakingStrategy(payable(pufferProtocol.getStrategyAddress(NO_RESTAKING)));
    }

    // Test setup
    function testSetup() public {
        address noRestakingStrategy = pufferProtocol.getStrategyAddress(NO_RESTAKING);
        assertEq(IPufferStrategy(noRestakingStrategy).NAME(), NO_RESTAKING, "bad name");
    }

    // Reverts for everybody else
    function testPostRewardsRootReverts(address sender, bytes32 merkleRoot, uint256 blockNumber) public {
        vm.assume(sender != address(guardiansSafe));

        vm.expectRevert();
        strategy.postRewardsRoot(merkleRoot, blockNumber);
    }

    // Works for guardians
    function testPostRewardsRoot(bytes32 merkleRoot, uint256 blockNumber) public {
        vm.assume(strategy.getLastProofOfRewardsBlock() < blockNumber);
        vm.startPrank(address(guardiansSafe));
        strategy.postRewardsRoot(merkleRoot, blockNumber);
    }

    // Donation should work
    function testDonation() public {
        (bool s,) = address(strategy).call{ value: 5 ether }("");
        assertTrue(s);
    }

    // Collecting rewards flow
    function testCollectRewards() public {
        _setupMerkleRoot();

        uint256[] memory blockNumbers = new uint256[](1);
        blockNumbers[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 16080000000000000;

        bytes32[][] memory merkleProofs = new bytes32[][](1);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = hex"298198477089f9ce85de12fe6747b5d26250dd855e1e7eb15f067ae57ad400b5";
        proof[1] = hex"32c9503e9b3e27152cbd70e660517e961b8b3b7fe580fa76fa2f883025e1a3e2";
        merkleProofs[0] = proof;

        assertEq(alice.balance, 0, "alice should start with zero balance");

        vm.startPrank(alice);
        strategy.collectRewards({
            node: alice,
            pubKeyHash: keccak256(bytes.concat(bytes32("alice"))),
            blockNumbers: blockNumbers,
            amounts: amounts,
            merkleProofs: merkleProofs
        });

        // Double claim in different transactions should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                NoRestakingStrategy.AlreadyClaimed.selector, blockNumbers[0], keccak256(bytes.concat(bytes32("alice")))
            )
        );
        strategy.collectRewards({
            node: alice,
            pubKeyHash: keccak256(bytes.concat(bytes32("alice"))),
            blockNumbers: blockNumbers,
            amounts: amounts,
            merkleProofs: merkleProofs
        });
        assertEq(alice.balance, 16080000000000000, "alice should end with 16080000000000000 eth");

        // Bob claiming with Alice's proof
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                NoRestakingStrategy.AlreadyClaimed.selector, blockNumbers[0], keccak256(bytes.concat(bytes32("alice")))
            )
        );
        strategy.collectRewards({
            node: bob,
            pubKeyHash: keccak256(bytes.concat(bytes32("alice"))),
            blockNumbers: blockNumbers,
            amounts: amounts,
            merkleProofs: merkleProofs
        });

        // Bob claiming with a valid proof that is not his
        vm.expectRevert(
            abi.encodeWithSelector(NoRestakingStrategy.NothingToClaim.selector, keccak256(bytes.concat(bytes32("bob"))))
        );
        strategy.collectRewards({
            node: bob,
            pubKeyHash: keccak256(bytes.concat(bytes32("bob"))),
            blockNumbers: blockNumbers,
            amounts: amounts,
            merkleProofs: merkleProofs
        });
    }

    function testDoubleClaimInSameTransaction() public {
        _setupMerkleRoot();

        uint256[] memory blockNumbers = new uint256[](2);
        blockNumbers[0] = 1;
        blockNumbers[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 16080000000000000;
        amounts[1] = 16080000000000000;

        bytes32[][] memory merkleProofs = new bytes32[][](2);
        bytes32[] memory proof = new bytes32[](2);
        bytes32[] memory proof2 = new bytes32[](2);
        proof[0] = hex"298198477089f9ce85de12fe6747b5d26250dd855e1e7eb15f067ae57ad400b5";
        proof[1] = hex"32c9503e9b3e27152cbd70e660517e961b8b3b7fe580fa76fa2f883025e1a3e2";
        proof2[0] = hex"298198477089f9ce85de12fe6747b5d26250dd855e1e7eb15f067ae57ad400b5";
        proof2[1] = hex"32c9503e9b3e27152cbd70e660517e961b8b3b7fe580fa76fa2f883025e1a3e2";
        merkleProofs[0] = proof;
        merkleProofs[1] = proof2;

        assertEq(alice.balance, 0, "alice should start with zero balance");

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                NoRestakingStrategy.AlreadyClaimed.selector, blockNumbers[0], keccak256(bytes.concat(bytes32("alice")))
            )
        );
        strategy.collectRewards({
            node: alice,
            pubKeyHash: keccak256(bytes.concat(bytes32("alice"))),
            blockNumbers: blockNumbers,
            amounts: amounts,
            merkleProofs: merkleProofs
        });
    }

    // Anybody should be able to claim for Charlie, Charlie should get ETH
    function testRewardsClaimingForAnotherUser(address msgSender) public assumeEOA(msg.sender) {
        _setupMerkleRoot();

        uint256[] memory blockNumbers = new uint256[](1);
        blockNumbers[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 16070000000000000;

        bytes32[][] memory merkleProofs = new bytes32[][](1);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = hex"23c812ec1c3edb02b46b62af473d75c341e2ceb95c39e712f5e24e97d4bcde4f";
        merkleProofs[0] = proof;

        assertEq(charlie.balance, 0, "charlie should start with zero balance");

        // Random msg.sender
        vm.startPrank(msgSender);
        strategy.collectRewards({
            node: charlie,
            pubKeyHash: keccak256(bytes.concat(bytes32("charlie"))),
            blockNumbers: blockNumbers,
            amounts: amounts,
            merkleProofs: merkleProofs
        });

        assertEq(charlie.balance, 16070000000000000, "charlie should end with 16070000000000000 balance");
    }

    // Alice Alice claims rewards with 2 proofs
    function testClaimingMultipleProofs() public {
        _setupMerkleRoot();

        uint256[] memory blockNumbers = new uint256[](2);
        blockNumbers[0] = 1;
        blockNumbers[1] = 150;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 16080000000000000;
        amounts[1] = 26080000000000000;

        bytes32[][] memory merkleProofs = new bytes32[][](2);
        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = hex"298198477089f9ce85de12fe6747b5d26250dd855e1e7eb15f067ae57ad400b5";
        proof1[1] = hex"32c9503e9b3e27152cbd70e660517e961b8b3b7fe580fa76fa2f883025e1a3e2";
        bytes32[] memory proof2 = new bytes32[](2);
        proof2[0] = hex"6d4b23e4f81df0bb176d65cd2456a1d19f123228558bfaf7767d66690d600923";
        proof2[1] = hex"e6914098f54129e35649cf5d7c62ab7afaa3a2c709e226f55d716e7a75c64ad2";
        merkleProofs[0] = proof1;
        merkleProofs[1] = proof2;

        assertEq(alice.balance, 0, "alice should start with zero balance");

        strategy.collectRewards({
            node: alice,
            pubKeyHash: keccak256(bytes.concat(bytes32("alice"))),
            blockNumbers: blockNumbers,
            amounts: amounts,
            merkleProofs: merkleProofs
        });

        assertEq(alice.balance, 42160000000000000, "alice should end non zero balance");
    }

    function testPostingRewardsForSameBlockReverts() public {
        bytes32 merkleRoot1 = hex"4059b3b5d8c24bf58c7fab0ea81c2cd8409d7a26d9dc2c75f464945681d81371";

        // Post two merkle roots
        vm.startPrank(address(guardiansSafe));
        strategy.postRewardsRoot(merkleRoot1, 1);
        vm.expectRevert(abi.encodeWithSelector(NoRestakingStrategy.InvalidBlockNumber.selector, 1));
        strategy.postRewardsRoot(merkleRoot1, 1);
    }

    function _setupMerkleRoot() public {
        // Script for generating merkle proofs is in `test/unit/NoRestakingStartegyProofs.js`
        // Merkle roots are hardcoded, we have two of them
        vm.deal(address(strategy), 1000 ether);

        bytes32 merkleRoot1 = hex"4059b3b5d8c24bf58c7fab0ea81c2cd8409d7a26d9dc2c75f464945681d81371";
        bytes32 merkleRoot2 = hex"361520123168ffc3c2d93e1eaaaa5188616fef4a47f68e868a7414f2c2350313";

        // Post two merkle roots
        vm.startPrank(address(guardiansSafe));
        strategy.postRewardsRoot(merkleRoot1, 1);
        strategy.postRewardsRoot(merkleRoot2, 150);
    }
}