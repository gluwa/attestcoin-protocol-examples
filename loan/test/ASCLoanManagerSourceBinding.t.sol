// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ASCLoanManagerHarness} from "./harness/ASCLoanManagerHarness.sol";
import {EvmV1Decoder} from "@gluwa/asc-contracts/contracts/common/EvmV1Decoder.sol";

/// @notice Regression tests for loan source-contract binding — fund/repay logs must come from the registered source contract.
contract ASCLoanManagerSourceBindingTest is Test {
    ASCLoanManagerHarness internal manager;

    bytes32 internal constant FUND_EVENT_SIGNATURE =
        0x9e71d2fb732e68272b7e74ecfd14638673c1d77e19a5d390a3ffff054d57c44b;
    bytes32 internal constant REPAY_EVENT_SIGNATURE =
        0x040cee90ee4799897c30ca04e5feb6fa43dbba9b6d084b4b257cdafd84ba013e;

    address internal registeredSource = address(0xA11CE);
    address internal spoofedSource = address(0xBAD);

    function setUp() public {
        manager = new ASCLoanManagerHarness();
        manager.registerSourceLoanContract(registeredSource);
    }

    function testFundLog_acceptsRegisteredEmitter() public view {
        uint256 loanId = manager.exposeProcessFundLogs(_fundLog(registeredSource, 42));
        assertEq(loanId, 42);
    }

    function testFundLog_rejectsUnregisteredSource() public {
        ASCLoanManagerHarness fresh = new ASCLoanManagerHarness();
        vm.expectRevert("Source loan contract not registered!");
        fresh.exposeProcessFundLogs(_fundLog(registeredSource, 1));
    }

    function testFundLog_rejectsWrongEmitter() public {
        vm.expectRevert("LoanFunded event not emitted by registered source loan contract!");
        manager.exposeProcessFundLogs(_fundLog(spoofedSource, 1));
    }

    function testRepayLog_acceptsRegisteredEmitter() public view {
        (uint256 loanId, uint256 amount) = manager.exposeProcessRepayLogs(_repayLog(registeredSource, 7, 1000));
        assertEq(loanId, 7);
        assertEq(amount, 1000);
    }

    function testRepayLog_rejectsWrongEmitter() public {
        vm.expectRevert("LoanRepaid event not emitted by registered source loan contract!");
        manager.exposeProcessRepayLogs(_repayLog(spoofedSource, 7, 1000));
    }

    function _fundLog(address emitter, uint256 loanId) internal pure returns (EvmV1Decoder.LogEntry[] memory logs) {
        logs = new EvmV1Decoder.LogEntry[](1);
        logs[0].address_ = emitter;
        logs[0].topics = new bytes32[](2);
        logs[0].topics[0] = FUND_EVENT_SIGNATURE;
        logs[0].topics[1] = bytes32(loanId);
        logs[0].data = "";
    }

    function _repayLog(address emitter, uint256 loanId, uint256 amount)
        internal
        pure
        returns (EvmV1Decoder.LogEntry[] memory logs)
    {
        logs = new EvmV1Decoder.LogEntry[](1);
        logs[0].address_ = emitter;
        logs[0].topics = new bytes32[](2);
        logs[0].topics[0] = REPAY_EVENT_SIGNATURE;
        logs[0].topics[1] = bytes32(loanId);
        logs[0].data = abi.encode(amount);
    }
}
