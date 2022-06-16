var shell = require("shelljs")

shell.exec("rm -r ./deploy/*")
shell.exec("cp ./scripts/upgrade/00_Upgrade_DURA.js  ./deploy/")
shell.exec("npx hardhat deploy --network kovan")
