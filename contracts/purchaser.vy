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

event UpdateCompass:
    old_compass: address
    new_compass: address

event UpdateRefundWallet:
    old_refund_wallet: address
    new_refund_wallet: address

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

@deploy
def __init__(router: address, weth: address, _initial_asset: address, _refund_wallet: address, _compass_evm: address):
    """
    @param router: The address of the Uniswap V3 Router02 contract.
    @param weth: The address of the WETH contract.
    @param refund_wallet_: The address to send refunds to.
    @param compass_evm_: The address of the Compass EVM contract.
    """
    ROUTER02 = router
    WETH9 = staticcall SwapRouter02(router).WETH9()
    ASSET = _initial_asset
    _decimals: uint8 = staticcall ERC20(ASSET).decimals()
    ASSET_DECIMALS_NUMERATOR = 10 ** 6 * DENOMINATOR // 10 ** convert(_decimals, uint256)
    self.refund_wallet = _refund_wallet
    self.compass_evm = _compass_evm
    log UpdateCompass(old_compass=empty(address), new_compass=_compass_evm)
    log UpdateRefundWallet(old_refund_wallet=empty(address), new_refund_wallet=_refund_wallet)

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
    _old_refund_wallet: address = self.refund_wallet
    self.refund_wallet = _new_refund_wallet
    log UpdateRefundWallet(old_refund_wallet=_old_refund_wallet, new_refund_wallet=_new_refund_wallet)

@external
def set_paloma():
    assert msg.sender == self.compass_evm and self.paloma == empty(bytes32) and len(msg.data) == 36, "Unauthorized"
    _paloma: bytes32 = convert(slice(msg.data, 4, 32), bytes32)
    self.paloma = _paloma
    log SetPaloma(paloma=_paloma)

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
    extcall Compass(self.compass_evm).send_token_to_paloma(_etf_token, _paloma, _etf_amount)
    log Sold(etf_token=_etf_token, etf_amount=_etf_amount, estimated_amount=_estimated_amount, recipient=_recipient)

@external
@payable
def __default__():
    pass
