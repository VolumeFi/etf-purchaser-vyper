# ETF Purchaser Contract

## Overview
This Vyper smart contract facilitates the purchase and sale of ETFs (Exchange-Traded Funds) on the Ethereum blockchain. It allows users to buy and sell ETFs using various assets, including Ether and ERC-20 tokens, with integration to the Compass cross-chain bridge for ETF token transfers.

## Contract Architecture

### State Variables
- `ASSET`: Immutable address of the primary asset (e.g., USDT)
- `ASSET_DECIMALS_NUMERATOR`: Conversion factor for asset decimals
- `ROUTER02`: Uniswap V3 Router02 address for token swaps
- `WETH9`: WETH contract address
- `refund_wallet`: Address to receive refunds and deposits
- `compass_evm`: Compass bridge contract address
- `paloma`: Cross-chain identifier (bytes32)
- `fee`: Fee amount for ETF operations
- `fee_receiver`: Address to receive fees

### External Dependencies
- **ERC20**: Standard ERC-20 token interface
- **SwapRouter02**: Uniswap V3 router for token swaps
- **Weth**: Wrapped Ether contract
- **Compass**: Cross-chain bridge contract

## Function Documentation

### Constructor
```vyper
@deploy
def __init__(_router: address, _initial_asset: address, _refund_wallet: address, _compass_evm: address, _fee: uint256, _fee_receiver: address)
```

**Purpose**: Initializes the contract with core parameters.

**Parameters**:
- `_router`: Uniswap V3 Router02 address
- `_initial_asset`: Primary asset address (e.g., USDT)
- `_refund_wallet`: Wallet to receive deposits and refunds
- `_compass_evm`: Compass bridge contract address
- `_fee`: Fee amount for ETF operations
- `_fee_receiver`: Address to receive fees

**Security Considerations**:
- Validates router address and retrieves WETH9 address
- Calculates asset decimal conversion factor
- Emits initialization events for transparency

**Usage Example**:
```python
# Deploy with USDT as primary asset
purchaser = project.purchaser.deploy(
    router="0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
    initial_asset="0xdAC17F958D2ee523a2206206994597C13D831ec7",  # USDT
    refund_wallet="0xCdE7fB746AF9C308F10D1df56caF45ac3048653c",
    compass="0x71956340a586db3afD10C2645Dbe8d065dD79AC8",
    fee=0,
    fee_address="0x7C303D43aDF7055ff3Ef88c525803D3ABBDD2860"
)
```

### Access Control Functions

#### `update_compass(_new_compass: address)`
**Purpose**: Updates the Compass bridge contract address.

**Access Control**: Only callable by current compass contract
**Security**: Validates SLC switch is unavailable before update

**Usage Example**:
```python
# Only callable by current compass contract
purchaser.update_compass(new_compass_address, sender=compass_contract)
```

#### `update_refund_wallet(_new_refund_wallet: address)`
**Purpose**: Updates the refund wallet address.

**Access Control**: Requires Paloma validation
**Security**: Validates new address is not zero

**Usage Example**:
```python
# Requires Paloma validation
purchaser.update_refund_wallet(new_wallet, sender=compass_contract)
```

#### `update_fee(_new_fee: uint256)`
**Purpose**: Updates the fee amount for ETF operations.

**Access Control**: Requires Paloma validation
**Security**: Validates fee is non-negative

**Usage Example**:
```python
# Requires Paloma validation
purchaser.update_fee(1000000, sender=compass_contract)  # 0.001 ETH
```

#### `update_fee_receiver(_new_fee_receiver: address)`
**Purpose**: Updates the fee receiver address.

**Access Control**: Requires Paloma validation
**Security**: Validates new address is not zero

**Usage Example**:
```python
# Requires Paloma validation
purchaser.update_fee_receiver(new_receiver, sender=compass_contract)
```

#### `set_paloma()`
**Purpose**: Sets the Paloma cross-chain identifier.

**Access Control**: Only callable by compass contract when paloma is not set
**Security**: Validates message data length and sender

**Usage Example**:
```python
# Only callable once by compass contract
purchaser.set_paloma(sender=compass_contract)
```

### ETF Creation Functions

#### `create_signle_etf(_token_name, _token_symbol, _token_description, _etf_ticker, _expense_ratio)`
**Purpose**: Creates a new single ETF with specified parameters.

**Parameters**:
- `_token_name`: ETF token name (max 64 chars)
- `_token_symbol`: ETF token symbol (max 32 chars)
- `_token_description`: ETF description (max 256 chars)
- `_etf_ticker`: ETF ticker symbol (max 40 chars)
- `_expense_ratio`: Expense ratio (max 1,000,000 = 100%)

**Security Considerations**:
- Validates all string parameters are non-empty
- Validates expense ratio ≤ 1,000,000
- Requires fee payment if fee > 0
- Refunds excess ETH sent

**Usage Example**:
```python
# Create single ETF with 0.5% expense ratio
purchaser.create_signle_etf(
    "Bitcoin ETF",
    "BTCETF",
    "Bitcoin Exchange Traded Fund",
    "BTCETF",
    5000,  # 0.5%
    value=0,  # No fee required
    sender=user
)
```

#### `register_single_etf(_etf_token_denom, _etf_token_name, _etf_token_symbol, _etf_token_description, _etf_ticker, _expense_ratio)`
**Purpose**: Registers an existing single ETF token.

**Parameters**:
- `_etf_token_denom`: ETF token denomination (max 96 chars)
- `_etf_token_name`: ETF token name (max 64 chars)
- `_etf_token_symbol`: ETF token symbol (max 32 chars)
- `_etf_token_description`: ETF description (max 256 chars)
- `_etf_ticker`: ETF ticker symbol (max 40 chars)
- `_expense_ratio`: Expense ratio (max 1,000,000 = 100%)

**Security Considerations**:
- Same validation as create_single_etf
- Used for registering pre-existing tokens

**Usage Example**:
```python
# Register existing single ETF
purchaser.register_single_etf(
    "factory/paloma1k8c2m5cn322akk5wy8lpt87dd2f4yh9afcd7pv/TICKER.123",
    "Bitcoin ETF",
    "BTCETF",
    "Bitcoin Exchange Traded Fund",
    "BTCETF",
    5000,  # 0.5%
    value=0,
    sender=user
)
```

#### `create_composite_etf(_etf_token_name, _etf_token_symbol, _etf_token_description, _expense_ratio, _token0_denom, _token0_position, _token1_denom, _token1_position)`
**Purpose**: Creates a new composite ETF with two underlying tokens.

**Parameters**:
- `_etf_token_name`: ETF token name (max 64 chars)
- `_etf_token_symbol`: ETF token symbol (max 32 chars)
- `_etf_token_description`: ETF description (max 256 chars)
- `_expense_ratio`: Expense ratio (max 1,000,000 = 100%)
- `_token0_denom`: First token denomination (max 96 chars)
- `_token0_position`: First token position percentage
- `_token1_denom`: Second token denomination (max 96 chars)
- `_token1_position`: Second token position percentage

**Security Considerations**:
- Validates all string parameters are non-empty
- Validates expense ratio ≤ 1,000,000
- Validates token positions > 0
- Validates token0 ≠ token1
- Validates positions sum to 100
- Requires fee payment if fee > 0

**Usage Example**:
```python
# Create 60/40 BTC/ETH composite ETF
purchaser.create_composite_etf(
    "Bitcoin Ethereum ETF",
    "BTCETH",
    "60% Bitcoin, 40% Ethereum ETF",
    3000,  # 0.3%
    "factory/paloma1k8c2m5cn322akk5wy8lpt87dd2f4yh9afcd7pv/BTC.123",
    60,
    "factory/paloma1k8c2m5cn322akk5wy8lpt87dd2f4yh9afcd7pv/ETH.456",
    40,
    value=0,
    sender=user
)
```

#### `register_composite_etf(_etf_token_denom, _etf_token_name, _etf_token_symbol, _etf_token_description, _expense_ratio, _token0_denom, _token0_position, _token1_denom, _token1_position)`
**Purpose**: Registers an existing composite ETF token.

**Parameters**: Same as create_composite_etf plus `_etf_token_denom`

**Security Considerations**:
- Same validation as create_composite_etf
- Used for registering pre-existing composite tokens

**Usage Example**:
```python
# Register existing composite ETF
purchaser.register_composite_etf(
    "factory/paloma1k8c2m5cn322akk5wy8lpt87dd2f4yh9afcd7pv/BTCETH.123",
    "Bitcoin Ethereum ETF",
    "BTCETH",
    "60% Bitcoin, 40% Ethereum ETF",
    3000,
    "factory/paloma1k8c2m5cn322akk5wy8lpt87dd2f4yh9afcd7pv/BTC.123",
    60,
    "factory/paloma1k8c2m5cn322akk5wy8lpt87dd2f4yh9afcd7pv/ETH.456",
    40,
    value=0,
    sender=user
)
```

### Trading Functions

#### `buy(_etf_token, _etf_amount, _amount_in, _recipient, _path, _min_amount)`
**Purpose**: Purchases ETF tokens using specified input asset.

**Parameters**:
- `_etf_token`: ETF token address to purchase
- `_etf_amount`: Amount of ETF tokens to purchase
- `_amount_in`: Amount of input asset to spend
- `_recipient`: Address to receive ETF tokens
- `_path`: Uniswap swap path (optional)
- `_min_amount`: Minimum output amount (optional)

**Security Considerations**:
- Validates all addresses are non-zero
- Validates amounts > 0
- Requires Paloma and refund wallet to be set
- Handles direct asset transfers and swaps via Uniswap
- Supports ETH/WETH conversions
- Applies decimal conversion for USD amount calculation
- Refunds excess ETH

**Usage Example**:
```python
# Buy ETF with USDT directly
purchaser.buy(
    etf_token="0x123...",
    etf_amount=1000000,  # 1 ETF token
    amount_in=50000000,  # 50 USDT
    recipient=user.address,
    sender=user
)

# Buy ETF with ETH via swap
path = b'\x00' * 20 + b'\x01' + b'\x00' * 20  # WETH -> USDT path
purchaser.buy(
    etf_token="0x123...",
    etf_amount=1000000,
    amount_in=50000000000000000000,  # 50 ETH
    recipient=user.address,
    path=path,
    min_amount=49000000,  # 49 USDT minimum
    value=50000000000000000000,  # 50 ETH
    sender=user
)
```

#### `sell(_etf_token, _etf_amount, _estimated_amount, _recipient)`
**Purpose**: Sells ETF tokens via Compass bridge.

**Parameters**:
- `_etf_token`: ETF token address to sell
- `_etf_amount`: Amount of ETF tokens to sell
- `_estimated_amount`: Estimated output amount
- `_recipient`: Address to receive proceeds

**Security Considerations**:
- Validates ETF token address and amount
- Requires Paloma to be set
- Transfers tokens to contract, approves Compass, then bridges
- Uses Compass.send_token_to_paloma for cross-chain transfer

**Usage Example**:
```python
# Sell ETF tokens
purchaser.sell(
    etf_token="0x123...",
    etf_amount=1000000,  # 1 ETF token
    estimated_amount=50000000,  # 50 USDT estimated
    recipient=user.address,
    sender=user
)
```

### Internal Helper Functions

#### `_paloma_check()`
**Purpose**: Validates Paloma cross-chain messages.

**Security**: Ensures sender is compass contract and Paloma identifier matches.

#### `_safe_approve(_token, _to, _value)`
**Purpose**: Safely approves token spending.

**Security**: Uses default_return_value=True for compatibility.

#### `_safe_transfer(_token, _to, _value)`
**Purpose**: Safely transfers tokens.

**Security**: Only transfers if value > 0, uses default_return_value=True.

#### `_safe_transfer_from(_token, _from, _to, _value)`
**Purpose**: Safely transfers tokens from another address.

**Security**: Only transfers if value > 0, uses default_return_value=True.

## Events

The contract emits the following events for transparency and off-chain tracking:

- `UpdateCompass`: Compass address updates
- `UpdateRefundWallet`: Refund wallet updates
- `UpdateFee`: Fee amount updates
- `UpdateFeeReceiver`: Fee receiver updates
- `SetPaloma`: Paloma identifier setting
- `Buy`: ETF purchase transactions
- `Sold`: ETF sale transactions
- `CreateSingleETF`: Single ETF creation
- `RegisterSingleETF`: Single ETF registration
- `CreateCompositeETF`: Composite ETF creation
- `RegisterCompositeETF`: Composite ETF registration

## Security Considerations

### Access Control
- Compass contract controls critical parameter updates
- Paloma validation required for sensitive operations
- Single-use Paloma setting prevents replay attacks

### Input Validation
- All string parameters validated for non-empty values
- Address parameters validated for non-zero values
- Numeric parameters validated for positive values
- Expense ratios capped at 1,000,000 (100%)

### Reentrancy Protection
- `@nonreentrant` decorator on all state-changing functions
- External calls made after state updates

### Fee Handling
- Fee validation before operations
- Automatic refund of excess ETH
- Fee receiver validation

### Token Operations
- Safe transfer patterns with default return values
- Proper approval and transfer sequences
- Decimal conversion handling

## Testing

### Prerequisites
- Python 3.8+
- Ape Framework
- Foundry (for forking)

### Running Tests
Currently, this repository does not contain test files. To add tests:

1. Create a `tests/` directory
2. Add test files with `test_` prefix
3. Run tests with: `ape test`

### Example Test Structure
```python
# tests/test_purchaser.py
import pytest
from ape import accounts, project

def test_constructor():
    # Test contract deployment
    pass

def test_buy_function():
    # Test ETF purchase
    pass

def test_sell_function():
    # Test ETF sale
    pass

def test_access_control():
    # Test access restrictions
    pass
```

### Deployment Scripts
The repository includes deployment scripts for multiple networks:
- `scripts/deploy_eth.py` - Ethereum mainnet
- `scripts/deploy_arb.py` - Arbitrum
- `scripts/deploy_base.py` - Base
- `scripts/deploy_bsc.py` - BSC
- `scripts/deploy_gnosis.py` - Gnosis Chain
- `scripts/deploy_op.py` - Optimism
- `scripts/deploy_polygon.py` - Polygon

To deploy:
```bash
# Load account
ape accounts load Deployer

# Deploy to specific network
ape run scripts/deploy_eth.py --network ethereum:mainnet
```

## Network Configuration

The contract supports deployment on multiple networks with fork testing capabilities:
- Ethereum (with Alchemy fork)
- Arbitrum (with Alchemy fork)
- BSC
- Gnosis Chain
- Base
- Optimism
- Polygon

## License
Apache 2.0
