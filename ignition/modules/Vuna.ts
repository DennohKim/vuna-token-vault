const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const VunaModule = buildModule("VunaModule", (m: any) => {
  const vunaVault = m.contract("VunaVault", ["$IERC20", "$IPool"]);
  
  const vuna = m.contract("Vuna", [
    ["$initialDepositTokens"],
    "$automate",
    "$lendingPool"
  ]);

  return { vunaVault, vuna };
});

module.exports = VunaModule;