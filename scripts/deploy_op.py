from ape import accounts, project, networks

def main():
    acct = accounts.load("Deployer")
    router = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"   # Uniswap V3 Router
    initial_asset = "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85"  # USDC
    refund_wallet = "0xCdE7fB746AF9C308F10D1df56caF45ac3048653c"
    compass = "0xa41886cFA7f2d8cE8Dc15670DDD25eD890822856" 

    with networks.parse_network_choice("optimism:mainnet:alchemy") as provider:
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
