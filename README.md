# Smart Contracts for AlloyX

![AlloyX, screenshot](https://storage.googleapis.com/alloyx_assets/alloyx_frontend.png)

Current version: v4.0

## Summary
DeFi yields. Stable assets. No lock-up period. 

Here’s how AlloyX works: 
 
Partners deposit USDC into the AlloyX vault and receive derivative tokens (DURA).

DURA tokens are backed by a diversified range of real-world assets and are uncorrelated with Bitcoin. They’re designed to be resistant to market shocks in crypto.

Repayments accumulate in the form of stable coins in the treasury, which can then be invested to purchase additional loan tokens.
DURA tokens follow the ERC20 standard, which means they can be traded in the liquidity pools of decentralized exchanges.
CRWN tokens are used to reward DURA holders for staking their DURA. CRWN tokens are backed by the token rewards that lending protocols issue for investing the DURA treasury on their protocol. DURA holders are free to buy and sell DURA at any time

There’s no lock-up period: Traditionally, partners deposit USDC, receive a loan token, and earn interest over a three-year lock-up period. AlloyX lets you deposit your USDC at any time and redeem your DURA tokens at the exchange rate on a first-come, first-served basis. Or, you can trade your tokens in partner liquidity pools. 

The v4.0 AlloyX smart contracts enable the storage of loan tokens that serve as the underlying assets for the DURA. As holders of the loan tokens, the AlloyX smart contract will be eligible for reward tokens. In the case of Goldfinch this is the GFI. The reward tokens serve as the underlying assets that support the CRWN token. CRWN tokens will be minted and unlocked via the AlloyX staking mechanism.

For a more detailed breakdown of the DURA and CRWN tokens refer to this document: https://www.notion.so/DURA-CRWN-bebe39e1bd7244c6b08175638f4c4d7d 

There are two types of loan tokens currently being stored in the smart contract. Both are issued by the Goldfinch protocol: 

**FIDU**

The first is the FIDU ERC20 token. This token represents the senior pool. Goldfinch participants who purchase FIDU have exposure to all of the pools and are protected by the Backer token. There is a share price on the FIDU that determines the asset value.

**Backer Token**

The second is the ERC721 Backer token. This token represents debt tied directly to a borrower pool on Goldfinch. We load the interfaces of the Goldfinch protocol to gather the NFT principal, redeemable, and redeemed amounts to determine the asset NAV.

Both of these tokens can be stored in the smart contract treasury. When a liquidity provider deposits USDC into our treasury, we mint DURA tokens at the current USDC value to the depositor. When new Goldfinch pools become available, the FIDU in the treasury will be used to purchase Backer tokens.

**AlloyxTreasury**

AlloyxTreasury Desk contains all the assets and methods to move or approve tokens, keeps track of all fees and methods to extract fee.

- earningGfiFee:   The entire fee in GFI collected when user calls claimReward
- repaymentFee:   The fee collected in USDC when selling out FIDU or withdraw from Junior token
- redemptionFee:  The fee collected in USDC when depositing DURA.
- duraToFiduFee:   The fee collected in USDC when converting from DURA to FIDU.
- getAllUsdcFees:  Get all fees in USDC token(repaymentFee+redemptionFee+duraToFiduFee).
- getAllGfiFees:  Get all fees in GFI format(earningGfiFee).
- transferERC20:  Transfer certain amount token of certain address to some other account.
- transferERC721: Transfer certain amount token of certain address to some other account.
- transferAllUsdcFees: transfer USDC fees including repaymentFee,redemptionFee,duraToFiduFee.
- transferAllGfiFees:  transfer Gfi fees including earningGfiFee.
- approveERC20: Approve certain amount token of certain address to some other account.
- approveERC721:  Approve certain amount token of certain address to some other account.
- migrateERC20:  Migrate certain ERC20 to an address.
- migrateAllERC721Enumerable:  Migrate all ERC721 to an address.
- getERC721EnumerableIdsOf:  Get the IDs of Pooltokens of an addresss.

**AlloyxExchange**

AlloyxExchange maintains the exchange information or key statistics of AlloyxTreasury。

- getTreasuryTotalBalanceInUsdc: All Alloy DURA Token Value in terms of USDC.
- alloyxDuraToUsdc:  Convert Alloyx DURA to USDC amount.
- usdcToAlloyxDura:  Convert USDC Amount to Alloyx DURA.
- getFiduBalanceInUsdc:  Fidu Value in Vault in term of USDC.

**Goldfinch Desk**

Goldfinch Desk handles all transactions with Goldfinch smart contracts.

- depositDuraForFidu:  An Alloy token holder can deposit their tokens and buy FIDU.
- depositDuraForPoolToken:   An Alloy token holder can deposit their tokens and buy back their previously deposited Pooltoken.
- depositPoolTokenForDura:   A Junior token holder can deposit their NFT for dura.
- depositPoolTokensForUsdc:   A Junior token holder can deposit their NFT for stable coin.
- purchasePoolToken(OnlyAdmin):   Purchase Junior token using USDC.
- purchaseJuniorTokenBeyondUsdcThreshold(OnlyAdmin):  Purchase Junior token when usdc is beyond threshold.
- purchasePoolTokenOnBestTranch(OnlyAdmin):  Purchase Junior token on the best tranch.
- withdrawFromJuniorToken(OnlyAdmin):  Widthdraw from junior token to get repayments.
- purchaseFIDU(OnlyAdmin):  Purchase FIDU.
- sellFIDU(OnlyAdmin): Sell senior token to redeem FIDU.
- getJuniorTokenValue: Using the Goldfinch contracts, read the principal, redeemed and redeemable values.
- getGoldFinchPoolTokenBalanceInUsdc: GoldFinch PoolToken Value in Value in term of USDC.
- transferTokenToDepositor: Send the token of the ID to address.
- isValidPool:  Using the PoolTokens interface, check if this is a valid pool.
- getTokensAvailableForWithdrawal: Get the tokenID array of depositor.
- getTokensAvailableCountForWithdrawal: Get the token count of depositor.

**StableCoin Desk**

StableCoin Desk handles all transactions using StableCoin.

- depositDuraForPoolToken:   An Alloy token holder can deposit their tokens and buy back their previously deposited Pooltoken.
- depositUSDCCoin:   A Liquidity Provider can deposit supported stable coins for Alloy Tokens.

**Stake Desk**

Stake Desk handles all transactions for staking.

- stake:   Stake more into the vault, which will cause the user's DURA token to transfer to treasury.
- unstake:   Unstake some from the vault, which will cause the vault to transfer DURA token back to message sender.
- claimAllAlloyxCRWN:   Claim all alloy CRWN tokens of the message sender, the method will mint the CRWN token of the claimable.
- claimAlloyxCRWN:  Claim certain amount of alloy CRWN tokens of the message sender, the method will mint the CRWN token of the claimable amount to message sender, and clear the past rewards to the remainder.
- claimReward: Claim certain amount of reward token based on alloy CRWN token, the method will burn the CRWN token of the amount of message sender, and transfer reward token to message sender.
- withdrawGfiFromPoolTokens:  Widthdraw GFI from Junior token
- withdrawGfiFromMultiplePoolTokens: Widthdraw GFI from Junior token.
- getRewardTokenCount: Get reward token count if the amount of CRWN tokens are claimed.
- totalClaimableAndClaimedCRWNToken: Total claimable and claimed CRWN tokens of all stakeholders.

**AlloyxStakeInfo**

AlloyxStakeInfo maintains the staking related data structure

- isStakeholder:  Check if an address is a stakeholder.
- addStakeholder:  Add a stakeholder.
- removeStakeholder: Remove a stakeholder.
- stakeOf: Retrieve the stake for a stakeholder.
- createStake: A method for a stakeholder to create a stake.
- addStake: Add stake for a staker
- removeStake: Remove stake for a staker
- resetStakeTimestampWithRewardLeft: Clear a stake of a holder with some leftover reward
- claimableCRWNToken: Claimable CRWN token amount of an address
- totalClaimableCRWNToken: Total claimable CRWN tokens of all stakeholders

**AlloyX Configuration**

The config information which contains all the relevant smart contracts and numeric configuration

- setAddress(OnlyAdmin):  Set the address of certain index.
- setNumber(OnlyAdmin):  Set the number of certain index.
- copyFromOtherConfig(OnlyAdmin): Copy from other config
- getAddress:  Get address for index
- getNumber:  Get number for index

## External Functions
Below are the external functions and a description of their utility. 

**Safeguards**

The AlloyVault uses the OpenZeppelin library to implement the following safety measures:

- Ownable: This feature lets us limit certain actions to the deployer of the contract
- AccessControl: Limit the operations only to certain user group
- SafeMath/Math: Provides safe math operators
- Pausable: Allows us to pause all operations inside of the smart contract


**Core Functionality**

- depositAlloyxDURATokens: This is a redemption function for DURA tokens. If there is USDC in the treasury, token holders can redeem their DURA tokens for USDC at the current exchange rate. We burn the tokens as a result.

- depositUSDCCoin: This is a deposit function that allows for the minting of DURA tokens. The USDC is currently saved in the treasury. In the future we will use this USDC to purchase loan tokens.

- depositNFTToken: Backer token holders can deposit their NFT in exchange for USDC, if there is USDC available in the treasury.

- purchaseJuniorToken & purchaseSeniorTokens: These functions are used to purchase loan tokens off of the Goldfinch protocol. 

- transferAlloyxOwnership: This onlyOwner function allows for the transfer of ownership of the DURA token when the contract is paused.

## ERC20s
We have basic ERC20s for both the DURA and CRWN tokens. For testing we also have mock GFI, FIDU and USDC in the repository.

## NAV function
In order to understand the exchange rate of the DURA token to USDC we need to understand the underlying asset value. We use the following function to determine the Net Asset Value:

- getAlloyxDURATokenBalanceInUSDC: This function uses a collection of inputs to determine the USDC value of the DURA token.
