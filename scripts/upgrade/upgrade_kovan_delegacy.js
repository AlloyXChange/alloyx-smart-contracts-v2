var shell = require("shelljs")

shell.exec("rm -r ./deploy/*")
shell.exec("cp ./scripts/upgrade/02_Upgrade_Delegacy.js  ./deploy/")
shell.exec("npx hardhat deploy --network kovan")
