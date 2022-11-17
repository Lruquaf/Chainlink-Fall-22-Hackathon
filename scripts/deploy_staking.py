from brownie import network, Staking, config
from scripts.helpful_scripts import get_account


def deploy():
    account = get_account()
    staking = Staking.deploy(
        config["networks"][network.show_active()]["link_token"],
        config["networks"][network.show_active()]["link_usdt_price_feed"],
        10,
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    print(f"Deployed at {staking.address}")


def main():
    deploy()
