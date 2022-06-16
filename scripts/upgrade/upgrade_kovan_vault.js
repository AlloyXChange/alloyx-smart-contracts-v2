var shell = require("shelljs")



shell.exec("rm -r ./deploy/*")
shell.exec("cp ./scripts/upgrade/03_Upgrade_Vault.js  ./deploy/")
shell.exec("npx hardhat deploy --network kovan")
