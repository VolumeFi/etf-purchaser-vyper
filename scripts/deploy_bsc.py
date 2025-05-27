from ape import accounts, project, networks

def main():
    acct = accounts.load("Deployer")
    router = "0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2"   # Uniswap V3 Router
    initial_asset = "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d"  # USDC
    refund_wallet = "0xCdE7fB746AF9C308F10D1df56caF45ac3048653c"
    compass = "0xEb1981B0bC9C8ED8eE5F95D5ad0494B848020413" 

    with networks.parse_network_choice("bsc:mainnet") as provider:
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
