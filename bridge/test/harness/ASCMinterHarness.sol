// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ASCMinter} from "../../contracts/sol/ASCMinter.sol";
import {EvmV1Decoder} from "@gluwa/asc-contracts/contracts/common/EvmV1Decoder.sol";
import {
    INativeQueryVerifier
} from "@gluwa/asc-contracts/contracts/write-ability/common/INativeQueryVerifier.sol";

contract ASCMinterHarness is ASCMinter {
    function exposeProcessBurnLogs(EvmV1Decoder.LogEntry[] memory burnLogs)
        external
        pure
        returns (address emitter, address from, uint256 value)
    {
        return _processBurnLogs(burnLogs);
    }

    function exposeProcessMint(bytes32 queryId, bytes memory encodedTransaction) external {
        _processMint(queryId, encodedTransaction);
    }

    function exposeComputeQueryId(
        uint64 chainKey,
        uint64 blockHeight,
        bytes32 merkleRoot,
        INativeQueryVerifier.MerkleProofEntry[] calldata siblings
    ) external view returns (bytes32) {
        return _computeQueryId(chainKey, blockHeight, merkleRoot, siblings);
    }

    function exposeMarkQueryProcessed(bytes32 queryId) external {
        processedQueries[queryId] = true;
    }
}
