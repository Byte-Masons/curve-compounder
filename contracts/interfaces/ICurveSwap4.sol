// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICurveSwap4 {
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external;
}
