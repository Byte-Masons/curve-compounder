// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICurveSwap {
    function coins(uint256 index) external returns (address);

    function underlying_coins(uint256 index) external returns (address);

    function claim_rewards() external;
}
