// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ASCMinterHarness} from "./harness/ASCMinterHarness.sol";
import {EvmV1Decoder} from "@gluwa/asc-contracts/contracts/common/EvmV1Decoder.sol";

contract ASCMinterBurnLogTest is Test {
    ASCMinterHarness internal minter;

    bytes32 internal constant BURN_EVENT_SIGNATURE =
        0x17dc4d6f69d484e59be774c29b47d2fa4c14af2e01df42fc5643ac968f4d427e;

    function setUp() public {
        minter = new ASCMinterHarness();
    }

    function testBurnLog_decodesRecipientAndAmount() public view {
        address token = address(0x1111);
        address burner = address(0x2222);
        uint256 amount = 50 ether;

        (address origin, address from, uint256 value) =
            minter.exposeProcessBurnLogs(_burnLog(token, burner, amount));

        assertEq(origin, token);
        assertEq(from, burner);
        assertEq(value, amount);
    }

    function testBurnLog_rejectsWrongEventSignature() public {
        EvmV1Decoder.LogEntry[] memory logs = _burnLog(address(0x1), address(0x2), 1);
        logs[0].topics[0] = bytes32(uint256(0xdead));

        vm.expectRevert("Not TokensBurnedForBridging event");
        minter.exposeProcessBurnLogs(logs);
    }

    function _burnLog(address token, address from, uint256 amount)
        internal
        pure
        returns (EvmV1Decoder.LogEntry[] memory logs)
    {
        logs = new EvmV1Decoder.LogEntry[](1);
        logs[0].address_ = token;
        logs[0].topics = new bytes32[](2);
        logs[0].topics[0] = BURN_EVENT_SIGNATURE;
        logs[0].topics[1] = bytes32(uint256(uint160(from)));
        logs[0].data = abi.encode(amount);
    }
}
