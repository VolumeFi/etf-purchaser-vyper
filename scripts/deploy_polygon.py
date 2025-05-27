from ape import accounts, project, networks

def main():
    acct = accounts.load("Deployer")
    router = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"   # Uniswap V3 Router
    initial_asset = "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"  # USDC
    refund_wallet = "0xCdE7fB746AF9C308F10D1df56caF45ac3048653c"
    compass = "0x6aC565F13FEE0f5D44D76036Aa6461Fb1A9D8b4B" 

    with networks.parse_network_choice("polygon:mainnet:alchemy") as provider:
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
