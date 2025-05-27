from ape import accounts, project, networks

def main():
    acct = accounts.load("Deployer")
    router = "0xc6D25285D5C5b62b7ca26D6092751A145D50e9Be"   # Uniswap V3 Router
    initial_asset = "0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83"  # USDC
    refund_wallet = "0xCdE7fB746AF9C308F10D1df56caF45ac3048653c"
    compass = "0xc2A1a1bD4018cFAA744dD5Fb9D0c06f460e1C63A" 

    with networks.parse_network_choice("gnosis:mainnet:alchemy") as provider:
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
