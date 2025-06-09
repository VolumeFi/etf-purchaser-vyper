from ape import accounts, project, networks

def main():
    acct = accounts.load("Deployer")
    router = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"   # Uniswap V3 Router
    # initial_asset = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC
    initial_asset = "0xdAC17F958D2ee523a2206206994597C13D831ec7"  # USDT
    refund_wallet = "0xCdE7fB746AF9C308F10D1df56caF45ac3048653c"
    compass = "0x71956340a586db3afD10C2645Dbe8d065dD79AC8" 

    with networks.parse_network_choice("ethereum:mainnet") as provider:
        priority_fee = int(networks.active_provider.priority_fee * 1.2)
        base_fee = int(networks.active_provider.base_fee * 1.2 + priority_fee)
        purchaser = project.purchaser.deploy(
            router,
            initial_asset,
            refund_wallet,
            compass,
            max_fee=base_fee,
            max_priority_fee=priority_fee,
            sender=acct,
            publish=True,
        )

        print(purchaser)
