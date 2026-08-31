// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ASCMintableToken, ASC_MINTER} from "./MintableToken.sol";
import {ASCBase} from "@gluwa/asc-contracts/contracts/readability/ASCBase.sol";
import {EvmV1Decoder} from "@gluwa/asc-contracts/contracts/common/EvmV1Decoder.sol";

/**
 * @title ASCMinter
 * @notice Simplified ASC that mints wrapped tokens after a proved source-chain burn.
 * @dev Mints only when the burn log's emitting contract (source-chain token) is whitelisted
 *      via {wrapOriginToken}. Unregistered emitters are rejected even if the proof is valid.
 */
contract ASCMinter is ASCBase {
    enum MinterActions {
        None, // 0 — holder
        Mint // 1
    }
    error InvalidAction(uint8 action);

    // TokensBurnedForBridging event signature: keccak256("TokensBurnedForBridging(address,uint256)")
    bytes32 public constant BURN_EVENT_SIGNATURE =
        0x17dc4d6f69d484e59be774c29b47d2fa4c14af2e01df42fc5643ac968f4d427e;

    event TokensMinted(address indexed wrappedTokenAddress, address indexed burntFrom, uint256 amount, bytes32 indexed queryId);
    event EmitterWhitelisted(address indexed emitter, address indexed wrappedToken);

    /// @notice Source-chain burn contracts allowed to trigger mints (log `address` / emitter).
    mapping(address => bool) public whitelistedEmitters;

    /// @notice Whitelisted emitter → wrapped ASCMintableToken on Creditcoin.
    mapping(address => address) public wrappedTokens;

    /**
     * @notice Whitelist a source-chain burn emitter and map it to a Creditcoin wrapped token.
     * @param originToken Source-chain ERC20 that emits `TokensBurnedForBridging` (the emitter).
     * @param targetToken Creditcoin ASCMintableToken that this ASC may mint.
     */
    function wrapOriginToken(address originToken, address targetToken) external {
        require(originToken != address(0), "Origin token cannot be the zero address");
        require(targetToken != address(0), "Target token cannot be the zero address");
        require(wrappedTokens[originToken] == address(0), "Origin token already wrapped");
        require(ASCMintableToken(targetToken).owner() == msg.sender, "Target token must be owned by the caller");
        require(ASCMintableToken(targetToken).hasRole(ASC_MINTER, address(this)), "Target token must be ASCMintableToken and support AccessControl");

        whitelistedEmitters[originToken] = true;
        wrappedTokens[originToken] = targetToken;

        emit EmitterWhitelisted(originToken, targetToken);
    }

    function _processAndEmitEvent(uint8 action, bytes32 queryId, bytes memory encodedTransaction) internal override {
        if (action == uint8(MinterActions.Mint)) {
            _processMint(queryId, encodedTransaction);
        } else {
            revert InvalidAction(action);
        }
    }

    function _processMint(bytes32 queryId, bytes memory encodedTransaction) internal {
        // Validate transaction type
        uint8 txType = EvmV1Decoder.getTransactionType(encodedTransaction);
        require(EvmV1Decoder.isValidTransactionType(txType), "Unsupported transaction type");
        // Decode and validate receipt status
        EvmV1Decoder.ReceiptFields memory receipt = EvmV1Decoder.decodeReceiptFields(encodedTransaction);
        require(receipt.receiptStatus == 1, "Transaction did not succeed");

        // Find burn events and validate
        EvmV1Decoder.LogEntry[] memory burnLogs =
            EvmV1Decoder.getLogsByEventSignature(receipt, BURN_EVENT_SIGNATURE);
        require(burnLogs.length > 0, "No burn events found");

        (address emitter, address burntFrom, uint256 burntValue) = _processBurnLogs(burnLogs);

        // Reject burns from contracts that were never whitelisted, even with a valid proof.
        require(whitelistedEmitters[emitter], "Emitter not whitelisted");

        address wrappedTokenAddress = wrappedTokens[emitter];
        require(wrappedTokenAddress != address(0), "No wrapped token for emitter");

        ASCMintableToken(wrappedTokenAddress).mint(burntFrom, burntValue);

        emit TokensMinted(wrappedTokenAddress, burntFrom, burntValue, queryId);
    }

    function _processBurnLogs(EvmV1Decoder.LogEntry[] memory burnLogs)
        internal
        pure
        returns (address emitter, address from, uint256 value)
    {
        // For this demonstration we only process the first burn log found within a transaction.
        // We only expect a single burn log per transaction in this demo anyways
        require(burnLogs.length > 0, "No burn logs");
        EvmV1Decoder.LogEntry memory log = burnLogs[0];

        require(log.topics.length == 2, "Invalid TokensBurnedForBridging topics");
        require(log.topics[0] == BURN_EVENT_SIGNATURE, "Not TokensBurnedForBridging event");

        // Log `address` is the source-chain contract that emitted the burn (the emitter).
        emitter = log.address_;
        from = address(uint160(uint256(log.topics[1])));

        // data is a single uint256 (32 bytes)
        require(log.data.length == 32, "Not burn event: data len");
        value = abi.decode(log.data, (uint256));

        return (emitter, from, value);
    }
}
