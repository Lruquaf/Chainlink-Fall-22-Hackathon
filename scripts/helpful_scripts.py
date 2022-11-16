from brownie import network, accounts, config, Contract, MockV3Aggregator


contract_to_mock = {"link_usdt_price_feed": MockV3Aggregator}
DECIMALS = 8
STARTING_PRICE = 200000000000
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local"]


def get_account(index=None, id=None, name=None):
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[0]
    if name:
        return accounts.add(config["wallets"][name])
    else:
        return accounts.add(config["wallets"]["from_key_test_1"])


def get_contract(contract_name):
    contract_type = contract_to_mock[contract_name]
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        contract_address = config["networks"][network.show_active()][contract_name]
        contract = Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi
        )
        return contract
    else:
        if len(contract_type) <= 0:
            deploy_mocks()
        return contract_type[-1]


def deploy_mocks():
    account = get_account()
    MockV3Aggregator.deploy(DECIMALS, STARTING_PRICE, {"from": account})
    print("Deployed!")
