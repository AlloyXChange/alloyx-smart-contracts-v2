var shell = require("shelljs");

shell.exec("rm -r ./deploy/*");
shell.exec("cp ./scripts/deploy/mainnet/*  ./deploy/");
shell.exec("npx hardhat deploy --network mainnet");
