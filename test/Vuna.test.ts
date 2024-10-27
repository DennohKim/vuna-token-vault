import { expect } from "chai";
import * as ethers from "ethers";
import { Contract, Signer, ContractFactory } from "ethers";

describe("Vuna", function () {
  let vuna: Contract;
  let mockLendingPool: Contract;
  let mockGelato: Contract;
  let mockERC20: Contract;
  let mockAaveToken: Contract;
  let owner: Signer;
  let addr1: Signer;

  beforeEach(async function () {
    [owner, addr1] = await new ethers.getSigners();

    // Deploy mock contracts
    const MockERC20 = await new ethers.getContractFactory("ERC20Mock");
    mockERC20 = await MockERC20.deploy("Mock USDC", "mUSDC");

    const MockAaveToken = await ethers.getContractFactory("MockAaveToken");
    mockAaveToken = await MockAaveToken.deploy("Mock aUSDC", "maUSDC", ethers.utils.parseEther("1.05"));

    const MockLendingPool = await ethers.getContractFactory("MockLendingPool");
    mockLendingPool = await MockLendingPool.deploy();

    const MockGelato = await ethers.getContractFactory("MockGelato");
    mockGelato = await MockGelato.deploy();

    // Set up mock lending pool
    await mockLendingPool.setAToken(mockERC20.address, mockAaveToken.address);

    // Deploy Vuna contract
    const Vuna = await ethers.getContractFactory("Vuna");
    vuna = await Vuna.deploy(
      [mockERC20.address],
      mockGelato.address,
      mockLendingPool.address
    );

    // Mint some tokens to the owner
    await mockERC20.mint(await owner.getAddress(), ethers.utils.parseEther("1000"));
  });

  it("Should create a savings goal", async function () {
    const what = "New Car";
    const why = "For commuting";
    const targetAmount = ethers.utils.parseEther("100");
    const targetDate = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60; // 1 year from now

    await vuna.setGoal(what, why, targetAmount, targetDate, mockERC20.address);

    const goalId = 0; // First goal
    const goal = await vuna.savingsGoals(goalId);

    expect(goal.what).to.equal(what);
    expect(goal.why).to.equal(why);
    expect(goal.targetAmount).to.equal(targetAmount);
    expect(goal.targetDate).to.equal(targetDate);
    expect(goal.depositToken).to.equal(mockERC20.address);
  });

  it("Should deposit funds into a savings goal", async function () {
    // Create a goal first
    const targetAmount = ethers.utils.parseEther("100");
    const targetDate = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;
    await vuna.setGoal("Test Goal", "Test Reason", targetAmount, targetDate, mockERC20.address);

    const goalId = 0;
    const depositAmount = ethers.utils.parseEther("10");

    // Approve Vuna to spend tokens
    await mockERC20.approve(vuna.address, depositAmount);

    // Deposit
    await vuna.deposit(goalId, depositAmount);

    // Check the deposit was successful
    const goal = await vuna.savingsGoals(goalId);
    expect(goal.currentAmount).to.equal(depositAmount);
  });

  // Add more tests here for other functionalities
});