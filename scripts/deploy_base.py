from ape import accounts, project, networks

def main():
    acct = accounts.load("Deployer")
    router = "0x2626664c2603336E57B271c5C0b26F421741e481"   # Uniswap V3 Router
    # initial_asset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"  # USDC
    initial_asset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"  # USDT
    refund_wallet = "0xCdE7fB746AF9C308F10D1df56caF45ac3048653c"
    compass = "0x105230D0ee3ADB4E07654Eb35ad88E32Be791814" 
    fee = 0
    fee_address = "0x7C303D43aDF7055ff3Ef88c525803D3ABBDD2860"
    
    with networks.parse_network_choice("base:mainnet:alchemy") as provider:
        priority_fee = int(networks.active_provider.priority_fee * 1.2)
        base_fee = int(networks.active_provider.base_fee * 1.2 + priority_fee)
        purchaser = project.purchaser.deploy(
            router,
            initial_asset,
            refund_wallet,
            compass,
            fee,
            fee_address,
            max_fee=base_fee,
            max_priority_fee=priority_fee,
            sender=acct,
            publish=True,
        )

        print(purchaser)
