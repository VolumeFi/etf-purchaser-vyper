from ape import accounts, project, networks

def main():
    acct = accounts.load("Deployer")
    router = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"   # Uniswap V3 Router
    # initial_asset = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"  # USDC
    initial_asset = "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9"  # USDT
    refund_wallet = "0xCdE7fB746AF9C308F10D1df56caF45ac3048653c"
    compass = "0x3c1864a873879139C1BD87c7D95c4e475A91d19C" 
    fee = 0
    fee_address = "0x7C303D43aDF7055ff3Ef88c525803D3ABBDD2860"
    
    with networks.parse_network_choice("arbitrum:mainnet:alchemy") as provider:
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
