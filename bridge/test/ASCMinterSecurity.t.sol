// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ASCMinterHarness} from "./harness/ASCMinterHarness.sol";
import {BridgeTestToken} from "../contracts/sol/BridgeTestToken.sol";

/// @notice Regression tests for bridge emitter whitelist and query replay dedupe (ASCBase).
contract ASCMinterSecurityTest is Test {
    ASCMinterHarness internal minter;

    address internal originEmitter = address(0xBEEF);
    address internal spoofedEmitter = address(0xBAD);

    function setUp() public {
        minter = new ASCMinterHarness();
    }

    function testEmitterWhitelist_rejectsUnregisteredEmitter() public {
        vm.expectRevert("Emitter not whitelisted");
        minter.exposeRequireWhitelistedEmitter(originEmitter);
    }

    function testEmitterWhitelist_acceptsAfterWrapOriginToken() public {
        BridgeTestToken wrapped = new BridgeTestToken(address(minter));
        minter.wrapOriginToken(originEmitter, address(wrapped));

        assertTrue(minter.whitelistedEmitters(originEmitter));
        assertEq(minter.wrappedTokens(originEmitter), address(wrapped));

        minter.exposeRequireWhitelistedEmitter(originEmitter);
    }

    function testEmitterWhitelist_rejectsSpoofedEmitterAfterWrap() public {
        BridgeTestToken wrapped = new BridgeTestToken(address(minter));
        minter.wrapOriginToken(originEmitter, address(wrapped));

        vm.expectRevert("Emitter not whitelisted");
        minter.exposeRequireWhitelistedEmitter(spoofedEmitter);
    }

    function testQueryDedupe_rejectsProcessedQueryId() public {
        bytes32 queryId = keccak256("tutorial-replay-test");
        minter.exposeMarkQueryProcessed(queryId);

        vm.expectRevert("Query already processed");
        minter.exposeRequireFreshQuery(queryId);
    }

    function testQueryDedupe_acceptsFreshQueryId() public view {
        bytes32 queryId = keccak256("fresh-query");
        minter.exposeRequireFreshQuery(queryId);
    }
}
