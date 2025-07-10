#pragma version 0.4.1
#pragma optimize gas
#pragma evm-version cancun
"""
@title ETF Purchaser
@license Apache 2.0
@author Volume.finance
"""

struct ExactInputParams:
    path: Bytes[204]
    recipient: address
    amountIn: uint256
    amountOutMinimum: uint256

interface ERC20:
    def decimals() -> uint8: view
    def balanceOf(_owner: address) -> uint256: view
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

interface SwapRouter02:
    def WETH9() -> address: pure
    def exactInput(params: ExactInputParams) -> uint256: payable

interface Weth:
    def deposit(): payable
    def withdraw(amount: uint256): nonpayable

interface Compass:
    def send_token_to_paloma(token: address, receiver: bytes32, amount: uint256): nonpayable
    def slc_switch() -> bool: view

DENOMINATOR: constant(uint256) = 10 ** 18
ASSET: public(immutable(address))
ASSET_DECIMALS_NUMERATOR: public(immutable(uint256))
ROUTER02: public(immutable(address))
WETH9: public(immutable(address))
refund_wallet: public(address)
compass_evm: public(address)
paloma: public(bytes32)
fee: public(uint256)
fee_receiver: public(address)

event UpdateCompass:
    old_compass: address
    new_compass: address

event UpdateRefundWallet:
    old_refund_wallet: address
    new_refund_wallet: address

event UpdateFee:
    old_fee: uint256
    new_fee: uint256

event UpdateFeeReceiver:
    old_fee_receiver: address
    new_fee_receiver: address

event SetPaloma:
    paloma: bytes32

event Buy:
    etf_token: address
    etf_amount: uint256
    usd_amount: uint256
    recipient: address

event Sold:
    etf_token: address
    etf_amount: uint256
    estimated_amount: uint256
    recipient: address

event CreateSingleETF:
    token_name: String[64]
    token_symbol: String[32]
    token_description: String[256]
    etf_ticker: String[40]
    expense_ratio: uint256

event RegisterSingleETF:
    etf_token_denom: String[96]
    etf_token_name: String[64]
    etf_token_symbol: String[32]
    etf_token_description: String[256]
    etf_ticker: String[40]
    expense_ratio: uint256

event CreateCompositeETF:
    etf_token_name: String[64]
    etf_token_symbol: String[32]
    etf_token_description: String[256]
    expense_ratio: uint256
    token0_denom: String[96]
    token0_position: uint256
    token1_denom: String[96]
    token1_position: uint256

event RegisterCompositeETF:
    etf_token_denom: String[96]
    etf_token_name: String[64]
    etf_token_symbol: String[32]
    etf_token_description: String[256]
    expense_ratio: uint256
    token0_denom: String[96]
    token0_position: uint256
    token1_denom: String[96]
    token1_position: uint256

@deploy
def __init__(_router: address, _initial_asset: address, _refund_wallet: address, _compass_evm: address, _fee: uint256, _fee_receiver: address):
    """
    @param router: The address of the Uniswap V3 Router02 contract.
    @param refund_wallet_: The address to send refunds to.
    @param compass_evm_: The address of the Compass EVM contract.
    """
    ROUTER02 = _router
    WETH9 = staticcall SwapRouter02(_router).WETH9()
    ASSET = _initial_asset
    _decimals: uint8 = staticcall ERC20(ASSET).decimals()
    ASSET_DECIMALS_NUMERATOR = 10 ** 6 * DENOMINATOR // 10 ** convert(_decimals, uint256)
    self.refund_wallet = _refund_wallet
    self.compass_evm = _compass_evm
    self.fee = _fee
    self.fee_receiver = _fee_receiver
    log UpdateCompass(old_compass=empty(address), new_compass=_compass_evm)
    log UpdateRefundWallet(old_refund_wallet=empty(address), new_refund_wallet=_refund_wallet)
    log UpdateFee(old_fee=0, new_fee=_fee)
    log UpdateFeeReceiver(old_fee_receiver=empty(address), new_fee_receiver=_fee_receiver)

@internal
def _paloma_check():
    assert msg.sender == self.compass_evm, "Not compass"
    assert self.paloma == convert(slice(msg.data, unsafe_sub(len(msg.data), 32), 32), bytes32), "Invalid paloma"

@internal
def _safe_approve(_token: address, _to: address, _value: uint256):
    assert extcall ERC20(_token).approve(_to, _value, default_return_value=True), "Failed approve"

@internal
def _safe_transfer(_token: address, _to: address, _value: uint256):
    if _value > 0:
        assert extcall ERC20(_token).transfer(_to, _value, default_return_value=True), "Failed transfer"

@internal
def _safe_transfer_from(_token: address, _from: address, _to: address, _value: uint256):
    if _value > 0:
        assert extcall ERC20(_token).transferFrom(_from, _to, _value, default_return_value=True), "Failed transferFrom"

@external
def update_compass(_new_compass: address):
    _compass: address = self.compass_evm
    assert msg.sender == _compass, "Not compass"
    assert not staticcall Compass(_compass).slc_switch(), "SLC is unavailable"
    self.compass_evm = _new_compass
    log UpdateCompass(old_compass=msg.sender, new_compass=_new_compass)

@external
def update_refund_wallet(_new_refund_wallet: address):
    self._paloma_check()
    assert _new_refund_wallet != empty(address), "Invalid refund wallet"
    _old_refund_wallet: address = self.refund_wallet
    self.refund_wallet = _new_refund_wallet
    log UpdateRefundWallet(old_refund_wallet=_old_refund_wallet, new_refund_wallet=_new_refund_wallet)

@external
def update_fee(_new_fee: uint256):
    self._paloma_check()
    assert _new_fee >= 0, "Invalid fee"
    _old_fee: uint256 = self.fee
    self.fee = _new_fee
    log UpdateFee(old_fee=_old_fee, new_fee=_new_fee)

@external
def update_fee_receiver(_new_fee_receiver: address):
    self._paloma_check()
    assert _new_fee_receiver != empty(address), "Invalid fee receiver"
    _old_fee_receiver: address = self.fee_receiver
    self.fee_receiver = _new_fee_receiver
    log UpdateFeeReceiver(old_fee_receiver=_old_fee_receiver, new_fee_receiver=_new_fee_receiver)

@external
def set_paloma():
    assert msg.sender == self.compass_evm and self.paloma == empty(bytes32) and len(msg.data) == 36, "Unauthorized"
    _paloma: bytes32 = convert(slice(msg.data, 4, 32), bytes32)
    self.paloma = _paloma
    log SetPaloma(paloma=_paloma)

@external
@payable
@nonreentrant
def create_single_etf(_token_name: String[64], _token_symbol: String[32], _token_description: String[256], _etf_ticker: String[40], _expense_ratio: uint256):
    assert _token_name != "", "Invalid token name"
    assert _token_symbol != "", "Invalid token symbol"
    assert _etf_ticker != "", "Invalid ETF ticker"
    assert self.fee_receiver != empty(address), "Fee receiver not set"
    assert _expense_ratio <= 1000000, "Invalid expense ratio"
    # transfer fee amount to fee receiver
    if self.fee > 0:
        assert msg.value >= self.fee, "Insufficient fee"
        if msg.value > self.fee:
            raw_call(msg.sender, b"", value=unsafe_sub(msg.value, self.fee))
        send(self.fee_receiver, self.fee)
    
    log CreateSingleETF(
        token_name=_token_name,
        token_symbol=_token_symbol,
        token_description=_token_description,
        etf_ticker=_etf_ticker,
        expense_ratio=_expense_ratio
    )

@external
@payable
@nonreentrant
def register_single_etf(_etf_token_denom: String[96], _etf_token_name: String[64], _etf_token_symbol: String[32], _etf_token_description: String[256], _etf_ticker: String[40], _expense_ratio: uint256):
    assert _etf_token_denom != "", "Invalid ETF token address"
    assert _etf_token_name != "", "Invalid ETF token name"
    assert _etf_token_symbol != "", "Invalid ETF token symbol"
    assert _etf_ticker != "", "Invalid ETF ticker"
    assert self.fee_receiver != empty(address), "Fee receiver not set"
    assert _expense_ratio <= 1000000, "Invalid expense ratio"
    # transfer fee amount to fee receiver
    if self.fee > 0:
        assert msg.value >= self.fee, "Insufficient fee"
        if msg.value > self.fee:
            raw_call(msg.sender, b"", value=unsafe_sub(msg.value, self.fee))
        send(self.fee_receiver, self.fee)

    log RegisterSingleETF(
        etf_token_denom=_etf_token_denom,
        etf_token_name=_etf_token_name,
        etf_token_symbol=_etf_token_symbol,
        etf_token_description=_etf_token_description,
        etf_ticker=_etf_ticker,
        expense_ratio=_expense_ratio
    )

@external
@payable
@nonreentrant
def create_composite_etf(_etf_token_name: String[64], _etf_token_symbol: String[32], _etf_token_description: String[256], _expense_ratio: uint256, _token0_denom: String[96], _token0_position: uint256, _token1_denom: String[96], _token1_position: uint256):
    assert _etf_token_name != "", "Invalid token name"
    assert _etf_token_symbol != "", "Invalid token symbol"
    assert _expense_ratio <= 1000000, "Invalid expense ratio"
    assert _token0_denom != "", "Invalid token0 denom"
    assert _token1_denom != "", "Invalid token1 denom"
    assert _token0_position > 0, "Invalid token0 position"
    assert _token1_position > 0, "Invalid token1 position"
    assert _token0_denom != _token1_denom, "Token0 and Token1 cannot be the same"
    assert _token0_position + _token1_position == 100, "Token pos must sum to 100"
    assert self.fee_receiver != empty(address), "Fee receiver not set"

    # transfer fee amount to fee receiver
    if self.fee > 0:
        assert msg.value >= self.fee, "Insufficient fee"
        if msg.value > self.fee:
            raw_call(msg.sender, b"", value=unsafe_sub(msg.value, self.fee))
        send(self.fee_receiver, self.fee)

    log CreateCompositeETF(
        etf_token_name=_etf_token_name,
        etf_token_symbol=_etf_token_symbol,
        etf_token_description=_etf_token_description,
        expense_ratio=_expense_ratio,
        token0_denom=_token0_denom,
        token0_position=_token0_position,
        token1_denom=_token1_denom,
        token1_position=_token1_position
    )

@external
@payable
@nonreentrant
def register_composite_etf(_etf_token_denom: String[96], _etf_token_name: String[64], _etf_token_symbol: String[32], _etf_token_description: String[256], _expense_ratio: uint256, _token0_denom: String[96], _token0_position: uint256, _token1_denom: String[96], _token1_position: uint256):
    assert _etf_token_denom != "", "Invalid ETF token address"
    assert _etf_token_name != "", "Invalid ETF token name"
    assert _etf_token_symbol != "", "Invalid ETF token symbol"
    assert _expense_ratio <= 1000000, "Invalid expense ratio"
    assert _token0_denom != "", "Invalid token0 denom"
    assert _token1_denom != "", "Invalid token1 denom"
    assert _token0_position > 0, "Invalid token0 position"
    assert _token1_position > 0, "Invalid token1 position"
    assert _token0_denom != _token1_denom, "Token0 and Token1 cannot be the same"
    assert _token0_position + _token1_position == 100, "Token pos must sum to 100"
    assert self.fee_receiver != empty(address), "Fee receiver not set"

    # transfer fee amount to fee receiver
    if self.fee > 0:
        assert msg.value >= self.fee, "Insufficient fee"
        if msg.value > self.fee:
            raw_call(msg.sender, b"", value=unsafe_sub(msg.value, self.fee))
        send(self.fee_receiver, self.fee)

    log RegisterCompositeETF(
        etf_token_denom=_etf_token_denom,
        etf_token_name=_etf_token_name,
        etf_token_symbol=_etf_token_symbol,
        etf_token_description=_etf_token_description,
        expense_ratio=_expense_ratio,
        token0_denom=_token0_denom,
        token0_position=_token0_position,
        token1_denom=_token1_denom,
        token1_position=_token1_position
    )

@external
@payable
@nonreentrant
def buy(_etf_token: address, _etf_amount: uint256, _amount_in: uint256, _recipient: address, _path: Bytes[204] = b"", _min_amount: uint256 = 0):
    assert _etf_token != empty(address), "Invalid from_token"
    assert _etf_amount > 0, "Invalid amount"
    assert _amount_in > 0, "Invalid amount_in"
    assert _recipient != empty(address), "Invalid recipient"
    assert self.paloma != empty(bytes32), "Paloma not set"
    assert self.refund_wallet != empty(address), "Refund wallet not set"

    _balance: uint256 = 0
    _admin: address = self.refund_wallet
    if _path == b"":
        if msg.value > 0:
            raw_call(msg.sender, b"", value=msg.value)
        self._safe_transfer_from(ASSET, msg.sender, _admin, _amount_in)
        _balance = _amount_in
    else:
        _from_token: address = convert(slice(_path, 0, 20), address)
        assert len(_path) >= 43, "Path error"
        if _from_token == WETH9 and msg.value >= _amount_in:
            if msg.value > _amount_in:
                raw_call(msg.sender, b"", value=unsafe_sub(msg.value, _amount_in))
            extcall Weth(WETH9).deposit(value=_amount_in)
        else:
            self._safe_transfer_from(_from_token, msg.sender, self, _amount_in)
        self._safe_approve(_from_token, ROUTER02, _amount_in)

        _balance = extcall SwapRouter02(ROUTER02).exactInput(ExactInputParams(
            path = _path,
            recipient = _admin,
            amountIn = _amount_in,
            amountOutMinimum = _min_amount
        ))
    
    _usd_amount: uint256 = _balance
    if ASSET_DECIMALS_NUMERATOR != DENOMINATOR:
        _usd_amount = _balance * ASSET_DECIMALS_NUMERATOR // DENOMINATOR
    assert _usd_amount > 0, "Insufficient deposit"
    log Buy(etf_token=_etf_token, etf_amount=_etf_amount, usd_amount=_usd_amount, recipient=_recipient)

@external
@nonreentrant
def sell(_etf_token: address, _etf_amount: uint256, _estimated_amount: uint256, _recipient: address):
    assert _etf_token != empty(address), "Invalid from_token"
    assert _etf_amount > 0, "Invalid amount"
    assert self.paloma != empty(bytes32), "Paloma not set"
    _compass: address = self.compass_evm
    _paloma: bytes32 = self.paloma
    self._safe_transfer_from(_etf_token, msg.sender, self, _etf_amount)
    self._safe_approve(_etf_token, _compass, _etf_amount)
    extcall Compass(_compass).send_token_to_paloma(_etf_token, _paloma, _etf_amount)
    log Sold(etf_token=_etf_token, etf_amount=_etf_amount, estimated_amount=_estimated_amount, recipient=_recipient)

@external
@payable
def __default__():
    pass
