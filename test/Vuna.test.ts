import { expect } from "chai";
import { ethers } from "ethers";
import { Contract, ContractFactory } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Vuna", function () {
  let Vuna: ContractFactory;
  let vuna: Contract;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  let MockERC20: ContractFactory;
  let mockToken: Contract;
  let MockLendingPool: ContractFactory;
  let mockLendingPool: Contract;
  let MockGelato: ContractFactory;
  let mockGelato: Contract;

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy mock contracts
    MockERC20 = await ethers.getContractFactory("ERC20Mock");
    mockToken = await MockERC20.deploy("Mock Token", "MTK");
    await mockToken.deployed();

    MockLendingPool = await ethers.getContractFactory("MockLendingPool");
    mockLendingPool = await MockLendingPool.deploy();
    await mockLendingPool.deployed();

    MockGelato = await ethers.getContractFactory("MockGelato");
    mockGelato = await MockGelato.deploy();
    await mockGelato.deployed();

    // Deploy the Vuna contract
    Vuna = await ethers.getContractFactory("Vuna");
    vuna = await Vuna.deploy(
      [mockToken.address],
      mockGelato.address,
      mockLendingPool.address
    );
    await vuna.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await vuna.owner()).to.equal(owner.address);
    });

    it("Should support the initial deposit token", async function () {
      const vunaVault = await vuna.vunaVaults(mockToken.address);
      expect(vunaVault).to.not.equal(ethers.constants.AddressZero);
    });

    it("Should set the correct lending pool", async function () {
      expect(await vuna.lendingPool()).to.equal(mockLendingPool.address);
    });
  });

  // Add more test cases here for other functionalities
});