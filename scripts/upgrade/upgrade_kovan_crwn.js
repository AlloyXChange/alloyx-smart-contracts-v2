var shell = require("shelljs")

shell.exec("rm -r ./deploy/*")
shell.exec("cp ./scripts/upgrade/01_Upgrade_CRWN.js  ./deploy/")
shell.exec("npx hardhat deploy --network kovan")
