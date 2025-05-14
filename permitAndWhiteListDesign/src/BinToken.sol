// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BinToken is ERC20, ERC20Permit {
    constructor() ERC20("bintoken", "Beth") ERC20Permit("ERC2612") {
        _mint(msg.sender, 1000 * 10 ** 18);
    }
}
