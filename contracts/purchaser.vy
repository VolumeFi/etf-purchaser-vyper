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
ROUTER02: public(immutable(address))
WETH9: public(immutable(address))
refund_wallet: public(address)
compass_evm: public(address)
paloma: public(bytes32)
withdraw_nonces: public(HashMap[uint256, bool])
deposit_nonce: public(uint256)

event UpdateCompass:
    old_compass: address
    new_compass: address

event UpdateRefundWallet:
    old_refund_wallet: address
    new_refund_wallet: address

event SetPaloma:
    paloma: bytes32

@deploy
def __init__(router: address, weth: address, _refund_wallet: address, _compass_evm: address):
    """
    @param router: The address of the Uniswap V3 Router02 contract.
    @param weth: The address of the WETH contract.
    @param refund_wallet_: The address to send refunds to.
    @param compass_evm_: The address of the Compass EVM contract.
    """
    ROUTER02 = router
    WETH9 = staticcall SwapRouter02(router).WETH9()
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
def deposit(recipient: bytes32, amount: uint256, path: Bytes[204] = b"", min_amount: uint256 = 0) -> uint256:
    return 0

@external
@nonreentrant
def withdraw(sender: bytes32, recipient: address, amount: uint256, nonce: uint256):
    pass

@external
@payable
def __default__():
    pass