// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRewardsGauge {
    function balanceOf(address arg0) external view returns (uint256);

    function claimed_reward(address _addr, address _token) external view returns (uint256);

    function claimable_reward(address _addr, address _token) external view returns (uint256);

    function claimable_reward_write(address _addr, address _token) external returns (uint256);

    function claim_rewards() external;

    function claim_rewards(address _addr) external;

    function claim_rewards(address _addr, address _receiver) external;

    function deposit(uint256 _value) external;

    function deposit(uint256 _value, address _addr) external;

    function deposit(
        uint256 _value,
        address _addr,
        bool _claim_rewards
    ) external;

    function withdraw(uint256 _value) external;

    function withdraw(uint256 _value, bool _claim_rewards) external;

    function reward_tokens(uint256 arg0) external view returns (address);

    function reward_balances(address arg0) external view returns (uint256);

    function rewards_receiver(address arg0) external view returns (address);
}
