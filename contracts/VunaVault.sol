// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";

contract VunaVault is ERC4626 {
    IPool public immutable lendingPool;

    constructor(IERC20 asset, IPool _lendingPool) ERC4626(asset) ERC20("Vuna Vault", "vVault") {
        lendingPool = _lendingPool;
    }

    function totalAssets() public view virtual override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + lendingPool.getReserveNormalizedIncome(address(asset()));
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        super._deposit(caller, receiver, assets, shares);
        IERC20(asset()).approve(address(lendingPool), assets);
        lendingPool.deposit(address(asset()), assets, address(this), 0);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal virtual override {
        lendingPool.withdraw(address(asset()), assets, address(this));
        super._withdraw(caller, receiver, owner, assets, shares);
    }
}