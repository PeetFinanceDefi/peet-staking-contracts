// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./interfaces/IERC20.sol";
import "./maths/SafeMath.sol";
import "./structures/PoolStruct.sol";
import "./libs/string.sol";

contract PeetStakingContract {
    using SafeMath for uint256;
    using strings for *;

    address private _poolManager;
    
    mapping(bytes32 => PoolStructure) private _pools;

    bytes32[] public allPoolsIndices;
    bytes32[] public activePoolsIndices;

    constructor(address manager) {
        _poolManager = manager;
    }

    event LogNewPublishedPool(
        bytes32 pool_indice,
        bytes32 pool_name,
        bool state,
        uint256 amount_reward,
        uint256 participation,
        uint256 startDate,
        uint256 endDate
    );

   event LogUpdatedPublishedPool(
        bytes32 pool_indice,
        bytes32 pool_name,
        bool state,
        uint256 amount_reward,
        uint256 participation,
        uint256 startDate,
        uint256 endDate
    );

    function removeActivePoolIndexation(uint index) private {
        if (index >= activePoolsIndices.length) return;
        PoolStructure storage pool = _pools[activePoolsIndices[index]];

        for (uint i = index; i < activePoolsIndices.length-1; i++){
            activePoolsIndices[i] = activePoolsIndices[i+1];
        }
    
        // emit disabled pool event
        emit LogUpdatedPublishedPool(
            pool.pool_indice,
            pool.pool_name,
            pool.pool_active,
            pool.rewards_pool.amount_reward,
            pool.funds_pool.max_total_participation,
            pool.start_date,
            pool.end_date
        );
    }

    function enableActivePoolIndexation(bytes32 indice, PoolStructure storage pool) private {
        activePoolsIndices.push(indice);

        // emit enabled pool event
        emit LogNewPublishedPool(
            pool.pool_indice,
            pool.pool_name,
            pool.pool_active,
            pool.rewards_pool.amount_reward,
            pool.funds_pool.max_total_participation,
            pool.start_date,
            pool.end_date
        );
    }

    function addPoolToIndexation(bytes32 indice, PoolStructure storage pool) private {
        // for all pool history
        allPoolsIndices.push(indice);

        // save the indice key in case the pool is already active at publishment
        if (pool.pool_active) {
            enableActivePoolIndexation(indice, pool);
        }
    }

    function fetchPoolByIndice(bytes32 indice) private view returns(PoolStructure storage) {
        return _pools[indice];
    }

    function getTotalWalletPoolInputAmount (bytes32 indice, address addr) public view returns(uint256) {
        PoolStructure storage pool = fetchPoolByIndice(indice);
        require(
            pool.pool_active == true,
            "Pool selected isn't active"
        );

        PoolWallet storage wallet = pool._wallets[addr];
        uint256 amountInPool = 0;
        for (uint256 i = 0; i < wallet.input_asset_amount.length; i++) {
            amountInPool += wallet.input_asset_amount[i];
        }
        return amountInPool;
    }

    function depositInPool(bytes32 indice, uint256 amount) public {
        PoolStructure storage pool = fetchPoolByIndice(indice);
        require(
            pool.pool_active == true,
            "Pool selected isn't active"
        );
        uint256 totalWalletPooled = getTotalWalletPoolInputAmount(indice, address(msg.sender)).add(amount);
        uint256 totalPoolInputAsset = pool.total_amount_input_pooled.add(amount);

        require(
            block.timestamp < pool.start_date,
            "Pool already started, you cant stake in this one!"
        );
        
        require(
            totalPoolInputAsset <= pool.funds_pool.max_total_participation,
            "Max pool cap already reached, you cant join this pool"
        );

        require(
            totalWalletPooled <= pool.funds_pool.max_wallet_participation,
            "Max wallet amount reached for this pool"
        );

        IERC20 input_token = IERC20(address(pool.input_asset));
        require(
            input_token.balanceOf(address(msg.sender)) >= amount,
            "Invalid funds to deposit in pools"
        );
        require(
            input_token.transferFrom(msg.sender, address(this), amount) == true,
            "Error transferFrom on the contract"
        );

        PoolWallet storage wallet = pool._wallets[address(msg.sender)];
        wallet.input_asset_amount.push(amount);
        wallet.start_date_pooled.push(block.timestamp);

        pool.total_amount_input_pooled.add(amount);
    }

    function calculateAndSendReward(bytes32 indice, address from, uint256 inputAmount) private view returns(uint256) {
        PoolStructure storage pool = fetchPoolByIndice(indice);
        uint256 weightPercent = inputAmount.mul(100).div(pool.funds_pool.max_wallet_participation).mul(10);
        uint256 reward = pool.rewards_pool.amount_reward * weightPercent / 10000;

        //TODO: transfers
        return reward;
    }

    function withdrawFromPool(bytes32 indice) public returns (uint256) {
        PoolStructure storage pool = fetchPoolByIndice(indice);
        require(
            block.timestamp > pool.end_date,
            "Pool end date isnt reached yet"
        );
        address sender = address(msg.sender);
        uint256 walletInputAmount = getTotalWalletPoolInputAmount(indice, sender);

        require (
            walletInputAmount > 0,
            "No funds to withdraw"
        );
        IERC20 input_token = IERC20(address(pool.input_asset));
        require(
            input_token.balanceOf(address(this)) >= walletInputAmount,
            "Invalid funds in the pool"
        );
        require(
            input_token.transfer(msg.sender, walletInputAmount) == true,
            "Error transfer on the contract"
        );

        // we reset the input amount just sent back
        PoolWallet storage wallet = pool._wallets[sender];
        for (uint256 i = 0; i < wallet.input_asset_amount.length; i++) {
            wallet.input_asset_amount[i] = 0;
        }

        return calculateAndSendReward(indice, sender, walletInputAmount);
    }

    function publishPool(bytes32 name, address in_asset,
        address out_asset, uint256 start_date, uint256 end_date,
        bool state_pool, uint256 amount_reward, uint max_wallet, uint max_total) public returns(bytes32) {
        
        require(
            msg.sender == _poolManager,
            "Not authorized to publish a new pool"
        );

        // IERC20 _reward_token = IERC20(address(out_asset));
        // require(
        //     _reward_token.balanceOf(address(this)) >= amount_reward,
        //     "Cant create this pool cause output asset rewards funds are too low"
        // );

        bytes32 pool_indice = keccak256(abi.encode(name,
          strings.uint2str(start_date), strings.uint2str(end_date)));

        // Pool base structure
        PoolStructure storage new_pool = _pools[pool_indice];
        new_pool.pool_indice = pool_indice;
        new_pool.pool_name = name;
        new_pool.input_asset = in_asset;
        new_pool.output_asset = out_asset;
        new_pool.start_date = start_date;
        new_pool.end_date = end_date;
        new_pool.pool_active = state_pool;
        
        // Pool Rewards
        PoolRewards memory rewards;
        rewards.amount_reward = amount_reward;
        new_pool.rewards_pool = rewards;
        //

        // Pool Funds
        PoolFunds memory funds;
        funds.max_wallet_participation = max_wallet;
        funds.max_total_participation = max_total;
        new_pool.funds_pool = funds;
        //

        addPoolToIndexation(pool_indice, _pools[pool_indice]);
        return pool_indice;
    }

    function fetchLivePools() public view returns(bytes32 [] memory, bytes32 [] memory, address [] memory,
    address [] memory, uint256 [] memory, uint256 [] memory) {
        bytes32 [] memory indices = new bytes32[](activePoolsIndices.length);
        bytes32 [] memory names = new bytes32[](activePoolsIndices.length);
        address [] memory input_assets = new address[](activePoolsIndices.length);
        address [] memory output_assets = new address[](activePoolsIndices.length);
        uint256 [] memory starts = new uint256[](activePoolsIndices.length);
        uint256 [] memory ends = new uint256[](activePoolsIndices.length);

        for (uint i = 0; i < activePoolsIndices.length; i++) {
            indices[i] =  _pools[activePoolsIndices[i]].pool_indice;
            names[i] =  _pools[activePoolsIndices[i]].pool_name;
            input_assets[i] = _pools[activePoolsIndices[i]].input_asset;
            output_assets[i] = _pools[activePoolsIndices[i]].output_asset;
            starts[i] = _pools[activePoolsIndices[i]].start_date;
            ends[i] = _pools[activePoolsIndices[i]].end_date;
        }
        return (indices, names, input_assets,
         output_assets, starts, ends);
    }
    
}