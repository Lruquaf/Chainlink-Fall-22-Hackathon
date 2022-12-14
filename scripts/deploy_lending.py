from brownie import network, Lending, config
from scripts.helpful_scripts import get_account


def deploy():
    account = get_account()
    lending = Lending.deploy(
        config["networks"][network.show_active()]["link_token"],
        config["networks"][network.show_active()]["usdt_token"],
        config["networks"][network.show_active()]["link_usdt_price_feed"],
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    print(f"Deployed at {lending.address}")


def main():
    deploy()
