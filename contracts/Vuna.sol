// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "./VunaVault.sol";
import "./gelato/AutomateTaskCreator.sol";
// import "hardhat/console.sol";

contract Vuna is ERC721Enumerable, AutomateTaskCreator, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;
    Counters.Counter private _tokenIdCounter;

    struct SavingsGoal {
        string what;
        string why;
        uint targetAmount;
        uint currentAmount;
        uint targetDate;
        address depositToken;
        bool complete;
    }

    struct AutomatedDeposit {
        uint amount;
        uint frequency;
        uint lastDeposit;
        bytes32 gelatoTaskId;
    }
    IPool public lendingPool;
    uint256 constant CHECK_DURATION = 10 minutes * 1000; // 10 min as milliseconds
    mapping(address => VunaVault) public vunaVaults;
    mapping(uint => SavingsGoal) public savingsGoals;
    mapping(uint => AutomatedDeposit) public automatedDeposits;

    event GoalCreated(address indexed saver, uint indexed goalId, string what, string why, uint targetAmount, uint targetDate, address depositToken);
    event GoalDeleted(address indexed saver, uint indexed goalId);
    event VunaVaultCreated(address indexed depositToken, address indexed VunaVault);
    event DepositMade(address indexed saver, uint indexed goalId, uint amount);
    event WithdrawMade(address indexed saver, uint indexed goalId, uint amount);
    event AutomatedDepositCreated(address indexed saver, uint indexed goalId, uint amount, uint frequency);
    event AutomatedDepositCanceled(address indexed saver, uint indexed goalId);
    event GoalCompleted(address indexed saver, uint indexed goalId, uint targetAmount);

   constructor(address[] memory _initialDepositTokens, address _automate, address _lendingPool) 
        ERC721("vuna", "VUNA") 
        AutomateTaskCreator(_automate) 
    {
        for (uint i = 0; i < _initialDepositTokens.length; i++) {
            _addDepositToken(_initialDepositTokens[i]);
        }
        lendingPool = IPool(_lendingPool);
    }

    function _addDepositToken(address _depositToken) internal {
        VunaVault _vunaVault = new VunaVault(IERC20(_depositToken), lendingPool);
        vunaVaults[_depositToken] = _vunaVault;
        emit VunaVaultCreated(_depositToken, address(_vunaVault));
    }

    modifier goalExists(uint goalId) {
        require(goalId < _tokenIdCounter.current(), "Goal does not exist");
        _;
    }

    modifier isGoalOwner(uint goalId) {
        require(msg.sender == ownerOf(goalId), "You are not the owner of this goal");
        _;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setGoal(
        string memory what, 
        string memory why, 
        uint targetAmount, 
        uint targetDate,
        address depositToken
    ) external {
        require(targetAmount > 0, "Target amount should be greater than 0");
        require(targetDate > block.timestamp, "Target date should be in the future");
        require(address(vunaVaults[depositToken]) != address(0), "Deposit token not supported");

        uint goalId = _tokenIdCounter.current();
        savingsGoals[goalId] = SavingsGoal(what, why, targetAmount, 0, targetDate, depositToken, false);
        _mint(msg.sender, goalId);
        _tokenIdCounter.increment();

        emit GoalCreated(msg.sender, goalId, what, why, targetAmount, targetDate, depositToken);
    }

    function deposit(uint goalId, uint amount) external goalExists(goalId) isGoalOwner(goalId) nonReentrant {
        SavingsGoal storage goal = savingsGoals[goalId];
        require(goal.depositToken != address(0), "Invalid deposit token");

        if(goal.currentAmount + amount >= goal.targetAmount) {
            goal.complete = true;
            emit GoalCompleted(msg.sender, goalId, goal.targetAmount);
        }

        _deposit(msg.sender, goal, amount);
        emit DepositMade(msg.sender, goalId, amount);
    }

    function withdraw(uint goalId) public goalExists(goalId) isGoalOwner(goalId) nonReentrant {
        SavingsGoal storage goal = savingsGoals[goalId];
        require(goal.currentAmount > 0, "No funds to withdraw");
        
        VunaVault vunaVault = vunaVaults[goal.depositToken];
        uint shares = vunaVault.balanceOf(address(this));
        uint assets = vunaVault.convertToAssets(shares);
        
        vunaVault.withdraw(assets, msg.sender, address(this));
        
        goal.currentAmount = 0;
        
        emit WithdrawMade(msg.sender, goalId, assets);
    }

    function automateDeposit(uint goalId, uint amount, uint frequency) external goalExists(goalId) {
        require(amount > 0, "Automated deposit amount should be greater than 0");
        require(frequency > 0, "Automated deposit frequency should be greater than 0");
        require(automatedDeposits[goalId].amount == 0, "Automated deposit already exists for this goal");

        AutomatedDeposit storage autoDeposit = automatedDeposits[goalId];
        autoDeposit.amount = amount;
        autoDeposit.frequency = frequency;
        autoDeposit.lastDeposit = block.timestamp; 

        bytes memory execData = abi.encodeWithSelector(this.automatedDeposit.selector, goalId);
        ModuleData memory moduleData = ModuleData({
            modules: new Module[](2), 
            args: new bytes[](2) 
        });

        moduleData.modules[0] = Module.PROXY;
        moduleData.modules[1] = Module.TRIGGER;
        moduleData.args[0] = _proxyModuleArg();
        moduleData.args[1] = _timeTriggerModuleArg(uint128(block.timestamp), uint128(CHECK_DURATION));

        bytes32 taskId = _createTask(
            address(this),
            execData,
            moduleData,
            address(0)
        );

        autoDeposit.gelatoTaskId = taskId;

        emit AutomatedDepositCreated(msg.sender, goalId, amount, frequency);
    }

    function cancelAutomatedDeposit(uint goalId) external goalExists(goalId) isGoalOwner(goalId) {
        _cancelAutomatedDeposit(goalId);
    }

    function _cancelAutomatedDeposit(uint goalId) internal {
        AutomatedDeposit memory autoDeposit = automatedDeposits[goalId];
        if (autoDeposit.gelatoTaskId != bytes32(0)) {
            _cancelTask(autoDeposit.gelatoTaskId);
            delete automatedDeposits[goalId];
            emit AutomatedDepositCanceled(msg.sender, goalId);
        }
    }

    function automatedDeposit(uint goalId) external goalExists(goalId) {
        AutomatedDeposit storage _automatedDeposit = automatedDeposits[goalId];
        uint amount = _automatedDeposit.amount;
        require(amount > 0, "No automated deposit for this goal");
        require(block.timestamp >= _automatedDeposit.lastDeposit + _automatedDeposit.frequency, "Deposit frequency not reached yet");

        SavingsGoal storage goal = savingsGoals[goalId];
        require(goal.currentAmount + amount <= goal.targetAmount, "Automated deposit exceeds the goal target amount");

        _deposit(ownerOf(goalId), goal, amount);

        if(goal.currentAmount >= goal.targetAmount) {
            goal.complete = true;
            emit GoalCompleted(ownerOf(goalId), goalId, goal.targetAmount);
        }

        _automatedDeposit.lastDeposit = block.timestamp;

        emit DepositMade(ownerOf(goalId), goalId, amount);
    }

    function _deposit(address account, SavingsGoal storage goal, uint amount) internal nonReentrant {
        address _depositToken = goal.depositToken;
        require(_depositToken != address(0), "Invalid deposit token");
        require(account != address(0), "Invalid account address");
        require(amount > 0, "Deposit amount should be greater than 0");
        require(IERC20(_depositToken).balanceOf(account) >= amount, "Insufficient balance");

        VunaVault vunaVault = vunaVaults[_depositToken];
        
        IERC20(_depositToken).safeTransferFrom(account, address(this), amount);
        IERC20(_depositToken).approve(address(vunaVault), amount);
        vunaVault.deposit(amount, address(this));
        
        goal.currentAmount += amount;
    }

    function balanceOf(uint _goalId) public view returns (uint) {
        SavingsGoal storage _goal = savingsGoals[_goalId];
        VunaVault vunaVault = vunaVaults[_goal.depositToken];
        uint shares = vunaVault.balanceOf(address(this));
        return vunaVault.convertToAssets(shares);
    }

    // function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
    //     require(from == address(0) || to == address(0), "Token transfer is not allowed");
    //     super._beforeTokenTransfer(from, to, tokenId, batchSize);
    // }

    function depositFundsTo1Balance(uint256 amount, address token) external {
        _depositFunds1Balance(amount, token, msg.sender);
    }
}