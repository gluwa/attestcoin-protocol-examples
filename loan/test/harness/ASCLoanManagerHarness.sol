// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ASCLoanManager} from "../../contracts/sol/ASCLoanManager.sol";
import {EvmV1Decoder} from "@gluwa/asc-contracts/contracts/common/EvmV1Decoder.sol";

/// @dev Test harness exposing internal log validators for source-contract binding tests.
contract ASCLoanManagerHarness is ASCLoanManager {
    function exposeProcessFundLogs(EvmV1Decoder.LogEntry[] memory fundLogs) external view returns (uint256) {
        return _processFundLogs(fundLogs);
    }

    function exposeProcessRepayLogs(EvmV1Decoder.LogEntry[] memory repayLogs)
        external
        view
        returns (uint256 loanId, uint256 amount)
    {
        return _processRepayLogs(repayLogs);
    }
}
