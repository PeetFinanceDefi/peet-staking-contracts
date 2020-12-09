// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./PoolReward.sol";
import "./PoolFund.sol";
import "./PoolWallet.sol";

struct PoolStructure {
    bytes32 pool_name; // Full name of the Pool
    address input_asset; // erc20 token from the input asset of the pool
    address output_asset; // erc20 token from the output asset for the pool (rewards)
    uint256 start_date; // Date on which the Peet pool will start
    uint256 end_date; // Date on which the Peet pool end, or start again with a renewal state

    bool pool_active; // Current pool state, available and activity
    bool pool_auto_renew; // On end_date a new pool can be started again with the wallets with auto hodler mode enabled

    PoolRewards rewards_pool; // Details about bonus given from this pool
    PoolFunds funds_pool; // Condition for this pool participation

    mapping(address => PoolWallet) _wallets;
}