// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ASCMinterHarness} from "./harness/ASCMinterHarness.sol";
import {BridgeTestToken} from "../contracts/sol/BridgeTestToken.sol";
import {EvmV1Decoder} from "@gluwa/asc-contracts/contracts/common/EvmV1Decoder.sol";
import {
    INativeQueryVerifier
} from "@gluwa/asc-contracts/contracts/write-ability/common/INativeQueryVerifier.sol";

/// @dev Stand-in for the Creditcoin native query verifier precompile (`0xFD2`) in unit tests.
contract MockNativeQueryVerifier {
    function calculateTxIndex(INativeQueryVerifier.MerkleProof calldata) external pure returns (uint64) {
        return 0;
    }

    function verifyAndEmit(
        uint64,
        uint64,
        bytes calldata,
        INativeQueryVerifier.MerkleProof calldata,
        INativeQueryVerifier.ContinuityProof calldata
    ) external pure returns (bool) {
        return false;
    }
}

/// @notice Regression tests for bridge emitter registration and query replay dedupe (ASCBase).
contract ASCMinterSecurityTest is Test {
    ASCMinterHarness internal minter;

    bytes32 internal constant BURN_EVENT_SIGNATURE =
        0x17dc4d6f69d484e59be774c29b47d2fa4c14af2e01df42fc5643ac968f4d427e;

    address internal constant VERIFIER_PRECOMPILE =
        0x0000000000000000000000000000000000000FD2;

    address internal originEmitter = address(0xBEEF);
    address internal spoofedEmitter = address(0xBAD);
    address internal burner = address(0xCAFE);

    function setUp() public {
        MockNativeQueryVerifier mock = new MockNativeQueryVerifier();
        vm.etch(VERIFIER_PRECOMPILE, address(mock).code);

        minter = new ASCMinterHarness();
    }

    function testEmitterRegistration_rejectsUnregisteredEmitter() public {
        bytes memory encoded = _encodedBurnTx(originEmitter, burner, 100);

        vm.expectRevert("No wrapped token for emitter");
        minter.exposeProcessMint(bytes32(0), encoded);
    }

    function testEmitterRegistration_acceptsAfterWrapOriginToken() public {
        BridgeTestToken wrapped = new BridgeTestToken(address(minter));
        minter.wrapOriginToken(originEmitter, address(wrapped));

        assertEq(minter.wrappedTokens(originEmitter), address(wrapped));

        bytes memory encoded = _encodedBurnTx(originEmitter, burner, 100);
        minter.exposeProcessMint(bytes32(uint256(1)), encoded);

        assertEq(wrapped.balanceOf(burner), 100);
    }

    function testEmitterRegistration_rejectsSpoofedEmitterAfterWrap() public {
        BridgeTestToken wrapped = new BridgeTestToken(address(minter));
        minter.wrapOriginToken(originEmitter, address(wrapped));

        bytes memory encoded = _encodedBurnTx(spoofedEmitter, burner, 100);

        vm.expectRevert("No wrapped token for emitter");
        minter.exposeProcessMint(bytes32(uint256(2)), encoded);
    }

    function testQueryDedupe_rejectsProcessedQueryId() public {
        uint64 chainKey = 1;
        uint64 blockHeight = 100;
        bytes32 merkleRoot = bytes32(uint256(42));
        INativeQueryVerifier.MerkleProofEntry[] memory siblings =
            new INativeQueryVerifier.MerkleProofEntry[](0);

        bytes32 queryId = minter.exposeComputeQueryId(chainKey, blockHeight, merkleRoot, siblings);
        minter.exposeMarkQueryProcessed(queryId);

        vm.expectRevert("Query already processed");
        minter.execute(
            0,
            chainKey,
            blockHeight,
            "",
            merkleRoot,
            siblings,
            bytes32(0),
            new bytes32[](0)
        );
    }

    function testQueryDedupe_acceptsFreshQueryId() public {
        uint64 chainKey = 1;
        uint64 blockHeight = 100;
        bytes32 merkleRoot = bytes32(uint256(43));
        INativeQueryVerifier.MerkleProofEntry[] memory siblings =
            new INativeQueryVerifier.MerkleProofEntry[](0);

        vm.expectRevert("Proof of inclusion verification failed");
        minter.execute(
            0,
            chainKey,
            blockHeight,
            "",
            merkleRoot,
            siblings,
            bytes32(0),
            new bytes32[](0)
        );
    }

    function _encodedBurnTx(address emitter, address from, uint256 amount)
        internal
        pure
        returns (bytes memory encoded)
    {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = BURN_EVENT_SIGNATURE;
        topics[1] = bytes32(uint256(uint160(from)));

        EvmV1Decoder.LogEntryTuple[] memory logs = new EvmV1Decoder.LogEntryTuple[](1);
        logs[0] = EvmV1Decoder.LogEntryTuple({
            address_: emitter,
            topics: topics,
            data: abi.encode(amount)
        });

        bytes[] memory chunks = new bytes[](3);
        chunks[0] = abi.encode(uint64(0), uint64(21_000), address(0x1), false, address(0x2), uint256(0), bytes(""));
        chunks[1] = abi.encode(uint128(1), uint256(27), bytes32(0), bytes32(0));
        chunks[2] = abi.encode(uint8(1), uint64(21_000), logs, bytes(""));

        encoded = abi.encode(uint8(0), chunks);
    }
}
