// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ASCMintableToken} from "./MintableToken.sol";

contract BridgeTestToken is ASCMintableToken {
    constructor(address minter) ASCMintableToken(minter, "Bridge Test Token", "BTKT") {}
}
