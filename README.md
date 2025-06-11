#ETF Purchaser Contract

##Overview
This contract is designed to facilitate the purchase of ETFs (Exchange-Traded Funds) on the Ethereum blockchain. It allows users to buy and sell ETFs using a variety of assets, including Ether and other ERC-20 tokens.

##Functionality

###The contract provides the following functionality:

 - Buy: Allows users to purchase ETFs using a specified asset.
 - Sell: Allows users to sell ETFs and receive a specified asset in return.
 - Create Single ETF: Allows the creation of a new single ETF.
 - Register Single ETF: Allows the registration of a new single ETF.
 - Create Composite ETF: Allows the creation of a new composite ETF.
 - Register Composite ETF: Allows the registration of a new composite ETF.
 - Update Compass: Allows the update of the Compass contract address.
 - Update Refund Wallet: Allows the update of the refund wallet address.
 - Update Fee: Allows the update of the fee amount.
 - Update Fee Receiver: Allows the update of the fee receiver address.

##Events

###The contract emits the following events:

 - Buy: Emitted when a user purchases an ETF.
 - Sell: Emitted when a user sells an ETF.
 - Create Single ETF: Emitted when a new single ETF is created.
 - Register Single ETF: Emitted when a new single ETF is registered.
 - Create Composite ETF: Emitted when a new composite ETF is created.
 - Register Composite ETF: Emitted when a new composite ETF is registered.
 - Update Compass: Emitted when the Compass contract address is updated.
 - Update Refund Wallet: Emitted when the refund wallet address is updated.
 - Update Fee: Emitted when the fee amount is updated.
 - Update Fee Receiver: Emitted when the fee receiver address is updated.

##Dependencies

###The contract depends on the following external contracts:

 - ERC20: The ERC20 token standard.
 - SwapRouter02: The Uniswap V3 SwapRouter02 contract.
 - Weth: The WETH contract.
 - Compass: The Compass contract.
