# Smart Contracts for AlloyX

Current version: v4.0

## Summary
DeFi yields. Stable assets. No lock-up period. 

Here’s how AlloyX works: 
 
Partners deposit USDC into the AlloyX vault and receive derivative tokens (DURA)
DURA tokens are backed by a diversified range of real-world assets and are uncorrelated with Bitcoin. They’re designed to be resistant to market shocks in crypto.
Repayments accumulate in the form of stable coins in the treasury, which can then be invested to purchase additional loan tokens.
DURA tokens are ERC 20, which means they can be traded in the liquidity pools of decentralized exchanges.
At the same time, AlloyX creates one reward token (CRWN) for every DURA
CRWN tokens are used to reward DURA holders for staking their DURA tokens
CRWN tokens are backed by the token rewards that lending protocols issue for investing the DURA treasury on their protocol
DURA holders are free to buy and sell DURA at any time

There’s no lock-up period: Traditionally, partners deposit USDC, receive a loan token, and earn interest over a three-year lock-up period. AlloyX lets you stake your USDC at any time and redeem your DURA tokens at the exchange rate on a first-come, first-served basis. Or, you can trade your tokens in partner liquidity pools. 

The v4.0 AlloyX smart contracts enable the storage of loan tokens that serve as the underlying assets for the DURA. As holders of the loan tokens, the AlloyX smart contract will be eligible for reward tokens. In the case of Goldfinch this is the GFI. The reward tokens serve as the underlying assets that support the CRWN token. CRWN tokens will be minted and unlocked via a yet to be developed staking mechanism.

For a more detailed breakdown of the DURA and CRWN tokens refer to this document: https://www.notion.so/DURA-CRWN-bebe39e1bd7244c6b08175638f4c4d7d 

There are two types of loan tokens currently being stored in the smart contract. Both are issued by the Goldfinch protocol: 

**FIDU**

The first is the FIDU ERC20 token. This token represents the senior pool. Goldfinch participants who purchase FIDU have exposure to all of the pools and are protected by the Backer token. There is a share price on the FIDU that determines the asset value.

**Backer Token**

The second is the ERC721 Backer token. This token represents debt tied directly to a borrower pool on Goldfinch. We load the interfaces of the Goldfinch protocol to gather the NFT principal, redeemable, and redeemed amounts to determine the asset NAV.

Both of these tokens can be stored in the smart contract treasury. When a liquidity provider deposits USDC into our treasury, we mint DURA tokens at the current USDC value to the depositor. The smart contract address will require whitelisting from Goldfinch as an accredited investor. This will allow the USDC that is deposited to purchase FIDU at the time of deposit. When new Goldfinch pools become available, the FIDU in the treasury will be used to purchase Backer tokens.

**Goldfinch Delegacy**
We use the Goldfinch Delegacy as a separate contract to interface with the Goldfinch smart contracts. 

**Staking Functions**
We support staking of DURA to earn CRWN.

- isStakeholder:  Check if an address is a stakeholder.
- addStakeholder:  Add a stakeholder.
- removeStakeholder: Remove a stakeholder.
- stakeOf: Retrieve the stake for a stakeholder.
- createStake: A method for a stakeholder to create a stake.
- addStake: Add stake for a staker
- removeStake: Remove stake for a staker
- addPastRedeemableReward: Add the stake to past redeemable reward
- stake: Stake more into the vault, which will cause the user's bronze token to transfer to vault
- unstake:  Unstake some from the vault, which will cause the vault to transfer bronze token back to message sender
- clearStake:  A method for a stakeholder to clear a stake.
- clearStakeWithRewardLeft: A method for a stakeholder to clear a stake with some leftover reward
- calculateRewardFromStake: Calculate stake
- claimableSilverToken: Claimable silver token amount of an address
- totalClaimableSilverToken: Total claimable silver tokens of all stakeholders
- totalClaimableAndClaimedSilverToken: Total claimable and claimed silver tokens of all stakeholders
- claimAllAlloyxSilver: Claim all alloy silver tokens of the message sender, the method will mint the silver token of the claimable amount to message sender, and clear the past rewards to zero
- claimAlloyxSilver:  Claim certain amount of alloy silver tokens of the message sender, the method will mint the silver token of the claimable amount to message sender, and clear the past rewards to the remainder
- claimReward: Claim certain amount of reward token based on alloy silver token, the method will burn the silver token of the amount of message sender, and transfer reward token to message sender

## External Functions
Below are the external functions and a description of their utility. 

**Safeguards**

The AlloyVault uses the OpenZeppelin library to implement the following safety measures:

- Ownable: This feature lets us limit certain actions to the deployer of the contract
- SafeMath/Math: Provides safe math operators
- Pausable: Allows us to pause all operations inside of the smart contract

**Token Management**

These external functions are only available to the contract owner and allow for the updating of the core token and pool addresses.

- changeAlloyxBronzeAddress (DURA)
- changeAlloyxSilverAddress (CRWN)
- changeSeniorPoolAddress
- changePoolTokenAddress

**Treasury Operation**

We want to control when the treasury starts minting DURA tokens so implement the following to have control over the ratio.

- startVaultOperation

**Core Functionality**

- depositAlloyxBronzeTokens: This is a redemption function for DURA tokens. If there is USDC in the treasury, token holders can redeem their DURA tokens for USDC at the current exchange rate. We burn the tokens as a result.

- depositUSDCCoin: This is a deposit function that allows for the minting of DURA tokens. The USDC is currently saved in the treasury. In the future we will use this USDC to purchase loan tokens.

- depositNFTToken: Backer token holders can deposit their NFT in exchange for USDC, if there is USDC available in the treasury.

- purchaseJuniorToken & purchaseSeniorTokens: In the future, these functions will be used to purchase loan tokens off of the Goldfinch protocol. The dependency here is that we need our treasury address whitelisted by Goldfinch.

- migrateGoldfinchPoolTokens & migrateERC20: These can both be used in the event of a contract upgrade or a worst case security measure. The contract owner can migrate assets to a chosen address.

- transferAlloyxOwnership: This onlyOwner function allows for the transfer of ownership of the DURA token when the contract is paused.

## ERC20s
We have basic ERC20s for both the DURA and CRWN tokens. For testing we also have mock GFI, FIDU and USDC in the repository.

## Internal NAV function
In order to understand the exchange rate of the DURA token to USDC we need to understand the underlying asset value. We use the following function to determine the Net Asset Value:

- getAlloyxBronzeTokenBalanceInUSDC: This internal function uses a collection of inputs to determine the USDC value of the DURA token.