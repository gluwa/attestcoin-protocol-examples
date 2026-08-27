// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ASCMinter} from "../../contracts/sol/ASCMinter.sol";
import {EvmV1Decoder} from "@gluwa/usc-contracts/contracts/common/EvmV1Decoder.sol";

contract ASCMinterHarness is ASCMinter {
    function exposeProcessBurnLogs(EvmV1Decoder.LogEntry[] memory burnLogs)
        external
        pure
        returns (address originTokenAddress, address from, uint256 value)
    {
        return _processBurnLogs(burnLogs);
    }
}
