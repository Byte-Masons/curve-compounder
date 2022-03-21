// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICurveRegistry {
    function get_lp_token(address pool) external view returns (address);

    function get_n_coins(address pool) external view returns (uint256[2] memory);
}
