// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

bytes32 constant ASC_MINTER = keccak256("ASC_MINTER");

abstract contract ASCMintableToken is ERC20, AccessControl, Ownable {
    constructor(address minter, string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
        _grantRole(ASC_MINTER, minter);
    }

    function mint(address to, uint256 amount) external onlyRole(ASC_MINTER) {
        _mint(to, amount);
    }
}
