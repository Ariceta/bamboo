pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./token/BambooToken.sol";


interface IMigratorKeeper {
    // Perform LP token migration from legacy UniswapV2 to BambooDeFi.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.
    // BambooDeFi must mint EXACTLY the same amount of BambooDeFi LP tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

// ZooKeeper is the master of pandas. He can make Bamboo and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once BAMBOO is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract ZooKeeper is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Total time rewards
    uint256 public constant TIME_REWARDS_LENGTH = 12;
    // Lock times available in seconds for 1 day, 7 days, 15 days, 30 days, 60 days, 90 days, 180 days, 1 year, 2 years, 3 years, 4 years, 5 years
    uint256[12] public timeRewards = [86400, 604800, 1296000, 2592000, 5184000, 7776000, 15550000, 31540000, 63070000, 94610000, 126100000, 157700000];
    // Lock times saved in a map, for quick validation
    mapping (uint256 => bool) public validTimeRewards;

    // Info of each user.
    struct  LpUserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of BAMBOOs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accBambooPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accBambooPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct  BambooDeposit {
        uint256 amount;             // How many BAMBOO tokens the user has deposited.
        uint256 lockTime;           // Time in seconds that need to pass before this deposit can be withdrawn.
        bool active;                // Flag for checking if this entry is actively staking.
    }

    struct BambooUserInfo {
        mapping (uint256 => BambooDeposit) deposits;    // Deposits from the user.
        uint256[] ids;                                  // Active deposits from the user.
        uint256 totalAmount;                           // Total amount of active deposits from the user.
    }

    struct StakeMultiplierInfo {
        uint256[TIME_REWARDS_LENGTH] multiplierBonus;       // Array of the different multipliers.
        bool registered;                                    // If this amount has been registered
    }

    struct YieldMultiplierInfo {
        uint256 multiplier;                                 // Multiplier value.
        bool registered;                                    // If this amount has been registered
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. BAMBOOs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that BAMBOOs distribution occurs.
        uint256 accBambooPerShare; // Accumulated BAMBOOs per share, times 1e12. See below.
    }

    // The BAMBOO TOKEN
    BambooToken public bamboo;
    // Dev address.
    address public devaddr;
    // BAMBOO tokens created per block.
    uint256 public bambooPerBlock;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorKeeper public migrator;


    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => LpUserInfo)) public userInfo;
    // Info of the additional multipliers for BAMBOO staking
    mapping (uint256 => StakeMultiplierInfo) public stakeMultipliers;
    // Info of the multipliers available for YieldFarming + staking
    mapping (uint256 => YieldMultiplierInfo) public yieldMultipliers;
    // Amounts registered for yield multipliers
    uint256[] public yieldAmounts;
    // Info of each user that stakes BAMBOO.
    mapping (address => BambooUserInfo) public bambooUserInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when BAMBOO mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event BAMBOODeposit(address indexed user, uint256 amount, uint256 lockTime, uint256 id);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event BambooWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        BambooToken _bamboo,
        address _devaddr,
        uint256 _bambooPerBlock,
        uint256 _startBlock
    ) public {
        bamboo = _bamboo;
        devaddr = _devaddr;
        bambooPerBlock = _bambooPerBlock;
        startBlock = _startBlock;
        for(uint i=0; i<TIME_REWARDS_LENGTH; i++) {
            validTimeRewards[timeRewards[i]] = true;
        }
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        checkPoolDuplicate ( _lpToken );
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accBambooPerShare: 0
        }));
    }

    // Update the given pool's BAMBOO allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorKeeper _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }


    // BambooDeFi setup

    // Add a new row of bamboo staking rewards. E.G. 500 (bamboos) -> [10001 (x1.0001*10000), ... ].
    // Adding an existing amount will repace it. The Array of TimeRewards must be of TIME_REWARDS_LENGTH.
    // Can only be called by the owner.
    function addStakeMultiplier(uint256 _amount, uint256[TIME_REWARDS_LENGTH] memory _multiplierBonuses ) public onlyOwner {
        uint mLength = _multiplierBonuses.length;
        require(mLength== TIME_REWARDS_LENGTH, "invalid array length");
        StakeMultiplierInfo memory mInfo = StakeMultiplierInfo({multiplierBonus: _multiplierBonuses, registered:true});
        stakeMultipliers[_amount] = mInfo;
    }

    // Add a new amount for yield farimng rewards. E.G. 500 (bamboos) -> 10001 (x1.0001*10000). Adding an existing amount will repace it.
    // Can only be called by the owner.
    function addYieldMultiplier(uint256 _amount, uint256 _multiplierBonus ) public onlyOwner {
        yieldAmounts.push(_amount);
        YieldMultiplierInfo memory mInfo = YieldMultiplierInfo({multiplier: _multiplierBonus, registered:true});
        yieldMultipliers[_amount] = mInfo;
    }

    // Callable functions for data visualization

    // Return reward multiplier over the given the time spent staking and the amount locked
    function getStakingMultiplier(uint256 _time, uint256 _amount) public view returns (uint256) {
        uint256 index = getTimeEarned(_time);
        StakeMultiplierInfo storage multiInfo = stakeMultipliers[_amount];
        require(multiInfo.registered, "amount: invalid amount");
        uint256 res = multiInfo.multiplierBonus[index];
        return res;
    }

    // Returns reward multiplier for yieldFarming + BambooStaking
    function getYieldMultiplier(uint256 _amount) public view returns (uint256) {
        uint256 key=0;
        for(uint i=0; i<yieldAmounts.length; i++) {
            if (_amount >= yieldAmounts[i] ) {
                key = yieldAmounts[i];
            }
        }
        if(key == 0) {
            return 10000;
        }
        else {
            return yieldMultipliers[key].multiplier;
        }
    }

    // Returns the active deposits from a user.
    function getDeposits(address _user) public view returns (uint256[] memory) {
        return bambooUserInfo[_user].ids;
    }

    // Returns the deposit amount and the minimum timestamp where the deposit can be withdrawn.
    function getDepositInfo(address _user, uint256 _id) public view returns (uint256, uint256) {
        BambooDeposit storage deposit = bambooUserInfo[_user].deposits[_id];
        require(deposit.active, "deposit does not exist");
        return (deposit.amount, _id+deposit.lockTime);
    }

    // View function to see pending BAMBOOs on frontend.
    function pendingBamboo(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        LpUserInfo storage user = userInfo[_pid][_user];
        uint256 bambooUserAmount = bambooUserInfo[_user].totalAmount;
        uint256 accBambooPerShare = pool.accBambooPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 yMultiplier = getYieldMultiplier(bambooUserAmount);
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number.sub(pool.lastRewardBlock);
            uint256 bambooReward = multiplier.mul(bambooPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accBambooPerShare = accBambooPerShare.add(bambooReward.mul(1e12).div(lpSupply));
        }
        uint256 pending = user.amount.mul(accBambooPerShare).div(1e12).sub(user.rewardDebt);
        return yMultiplier.mul(pending).div(10000);
    }

    // View function to see pending BAMBOOS to claim on staking. Returns amount of bamboo and minimum timestamp of claim
    function pendingStakeBamboo(uint256 _id, address _user) public view returns (uint256, uint256) {
        BambooUserInfo storage user = bambooUserInfo[_user];
        require(user.deposits[_id].active, "staking: invalid id");
        uint256 depositEnd = _id + user.deposits[_id].lockTime;
        uint256 multiplier = getStakingMultiplier(user.deposits[_id].lockTime, user.deposits[_id].amount);
        uint256 pending = multiplier.mul(user.deposits[_id].amount).div(10000);
        return (pending, depositEnd);
    }



    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number.sub(pool.lastRewardBlock);
        uint256 bambooReward = multiplier.mul(bambooPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        bamboo.mint(address(this), bambooReward);
        pool.accBambooPerShare = pool.accBambooPerShare.add(bambooReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit Functions

    // Deposit LP tokens to ZooKeeper for BAMBOO allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        require ( _pid < poolInfo.length , " keeper : pool exists ?" ) ;
        PoolInfo storage pool = poolInfo[_pid];
        LpUserInfo storage user = userInfo[_pid][msg.sender];
        uint256 bambooUserAmount = bambooUserInfo[msg.sender].totalAmount;
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 multiplier = getYieldMultiplier(bambooUserAmount);
            uint256 pending = user.amount.mul(pool.accBambooPerShare).div(1e12).sub(user.rewardDebt);
            uint256 finalPending = multiplier.mul(pending).div(10000);
            if(finalPending > 0) {
                bamboo.mint(address(this), finalPending - pending);
                safeBambooTransfer(msg.sender, finalPending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBambooPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Deposit Bamboo to ZooKeeper for additional staking rewards. Bamboos should be approved
    function depositBamboo(uint256 _amount, uint256 _lockTime) public{
        require(stakeMultipliers[_amount].registered, "staking: invalid amount");
        require(validTimeRewards[_lockTime] , "staking: invalid lockTime");
        BambooUserInfo storage user = bambooUserInfo[msg.sender];
        require(!user.deposits[block.timestamp].active, "staking: only 1 deposit per block!");
        if(_amount > 0) {
            IERC20(bamboo).safeTransferFrom(address(msg.sender), address(this), _amount);
            BambooDeposit memory depositData = BambooDeposit({amount: _amount, lockTime: _lockTime, active: true });
            user.ids.push(block.timestamp);
            user.deposits[block.timestamp] = depositData;
            user.totalAmount += _amount;
        }
        emit BAMBOODeposit(msg.sender, _amount, _lockTime, block.timestamp);
    }

    // Withdraw Functions

    // Withdraw LP tokens from ZooKeeper.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        LpUserInfo storage user = userInfo[_pid][msg.sender];
        uint256 bambooUserAmount = bambooUserInfo[msg.sender].totalAmount;
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 multiplier = getYieldMultiplier(bambooUserAmount);
        uint256 pending = user.amount.mul(pool.accBambooPerShare).div(1e12).sub(user.rewardDebt);
        uint256 finalPending = multiplier.mul(pending).div(10000);
        if(finalPending > 0) {
            bamboo.mint(address(this), finalPending - pending);
            safeBambooTransfer(msg.sender, finalPending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBambooPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw a Bamboo deposit from ZooKeeper.
    function withdrawBamboo(uint256 _depositId) public {
        BambooUserInfo storage user = bambooUserInfo[msg.sender];
        require(user.deposits[_depositId].active, "staking: invalid id");
        uint256 depositEnd = _depositId + user.deposits[_depositId].lockTime;
        // Get the depositIndex for deleting it later from the active ids
        uint depositIndex = 0;
        for (uint i=0; i<user.ids.length; i++){
            if (user.ids[i] == _depositId){
                depositIndex = i;
                break;
            }
        }
        require(user.ids[depositIndex] == _depositId, "staking: invalid id");
        // User cannot withdraw before the lockTime
        require(block.timestamp >= depositEnd, "staking: cannot withdraw yet!");
        uint256 multiplier = getStakingMultiplier(user.deposits[_depositId].lockTime, user.deposits[_depositId].amount);
        uint256 pending = multiplier.mul(user.deposits[_depositId].amount).div(10000);
        bamboo.mint(address(this), pending - user.deposits[_depositId].amount );
        safeBambooTransfer(msg.sender, pending);
        // Clean up the removed deposit
        user.ids[depositIndex] = user.ids[user.ids.length -1];
        user.ids.pop();
        user.totalAmount -= user.deposits[_depositId].amount;
        delete user.deposits[_depositId];
        emit BambooWithdraw(msg.sender, _depositId, pending);
    }


    // Withdraw LPs without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        LpUserInfo storage user = userInfo[_pid][msg.sender];
        uint256 _amount=user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    // Return the index of the time reward that can be claimed.
    function getTimeEarned(uint256 _time) internal view returns (uint256) {
        require(_time >= timeRewards[0], "time rewards: invalid time");
        uint256 index=0;
        for(uint i=1; i<TIME_REWARDS_LENGTH; i++) {
            if (_time >= timeRewards[i] ) {
                index = i;
            }
            else{
                break;
            }
        }
        return index;
    }

    // Safe bamboo transfer function, just in case if rounding error causes pool to not have enough BAMBOOs.
    function safeBambooTransfer(address _to, uint256 _amount) internal {
        uint256 bambooBal = bamboo.balanceOf(address(this));
        if (_amount > bambooBal) {
            bamboo.transfer(_to, bambooBal);
        } else {
            bamboo.transfer(_to, _amount);
        }
    }

    function checkPoolDuplicate ( IERC20 _lpToken ) public view{
        uint256 length = poolInfo.length ;
        for ( uint256 pid = 0; pid < length ; ++pid ) {
            require (poolInfo[pid].lpToken != _lpToken , "add: existing pool?");
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    // Claim ownership for token
    function claimToken(address _bambooaddr) public onlyOwner{
        require(BambooToken(_bambooaddr) == bamboo, "invalid address: not good");
        bamboo.claimOwnership();
    }
}
