<script>
    import "../global.css";
    import { ethers } from "ethers";
    import { aggregatorV3InterfaceABI } from "../ABI/aggregatorV3InterfaceABI";
    import { ERC20_ABI } from "../ABI/ierc20ABI";
    import { stakeABI } from "../ABI/stakeABI";
    
    const contractAddress = "0x4ce073aef35C28DA7672DCb36c325cEC35bC871A";
    const tokenAddress = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB";

    let contract;
    let provider;
    let button = "Connect Wallet";
    let signer;
    let linkPrice;
    let signerAddress;
    let tokenContract;
    let tokenBalance = 0;
    let accountBalance = 0;
    let isConnected = false;
    let isUnlocked = false;
    let initialized = false;
    let isPermanentlyDisconnected = false;

    async function connectWallet() {
        const { ethereum } = window;

        if (typeof window.ethereum !== "undefined") {
            // connect
            await ethereum.request({ method: "eth_requestAccounts" }).catch((err) => {
                if (err.code === 4001) {
                    // EIP-1193 userRejectedRequest
                    alert("You need to install MetaMask");
                } else {
                    console.error(err);
                }
            });

            // get provider
            provider = new ethers.providers.Web3Provider(ethereum);
            
            // get signer
            signer = provider.getSigner();

            contract = new ethers.Contract(contractAddress, stakeABI, signer);

            // get connected wallet address
            signerAddress = await signer.getAddress();

            // get account balance
            accountBalance = await provider.getBalance(signerAddress);

            // erc-20 token
            tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
            tokenBalance = await tokenContract.balanceOf(signerAddress);

            // update on account change
            ethereum.on("accountsChanged", function (accounts) {
                signerAddress = accounts[0];
            });

            verifyConnection();
        } else {
            alert("MetaMask has not been detected in your browser!");
            console.err("MetaMask has not been detected in your browser!");
        }
    }

    function verifyConnection() {
        ({ isConnected, isUnlocked, initialized, isPermanentlyDisconnected } = window.ethereum._state);

        if (isConnected && !isPermanentlyDisconnected && initialized) {
            if (isUnlocked) {
                // erc-20 token balance
                tokenContract.balanceOf(signerAddress).then((_tokenBalance) => {
                    tokenBalance = ethers.utils.formatEther(_tokenBalance);
                });

                getPrice();

                button = "Connected";
            }
            else {
                alert("Please unlock your MetaMask and reload");
            }
        } 
    }

    const addr = "0x48731cF7e84dc94C5f84577882c14Be11a5B7456";
    
    async function getPrice() {
        const priceFeed = new ethers.Contract(addr, aggregatorV3InterfaceABI, provider)

        priceFeed.latestRoundData().then((roundData) => {
            // Do something with roundData
            linkPrice = Number(BigInt(roundData.answer)) / 100000000;
            console.log(linkPrice);
        });
    }

    let amount = '';
    let selected;

    async function stakeToken() {
        if (isConnected && !isPermanentlyDisconnected && initialized) {
            if (isUnlocked) {
                const transaction = await contract.stakeToken(Number(amount), Number(selected));
                await transaction.wait();
            }
        }
    }

    let container;

    async function getStake() {
        if (isConnected && !isPermanentlyDisconnected && initialized) {
            if (isUnlocked) {
                const stakes = await contract.getStake(signerAddress);
                let until = 0;

                if (Number(BigInt(stakes.lockEndTime)) != 0) {
                    let format = new Date(stakes.lockEndTime);
                    until = format
                }

                container = `
                    <p>Staked Amount: <span>${ethers.utils.formatEther(stakes.lockedAmount)}</span></p>
                    <p>Locked Duration: <span>${stakes.lockDuration} Days</span></p>
                    <p>Locked Price: <span>${(Number(BigInt(stakes.lockedPrice)) / (10**8)).toFixed(2)}</span></p>
                    <p>locked until now: <span>${stakes.lockedApr}</span></p>
                    <p>Apr: <span>${stakes.lockedApr}</span></p>
                `;
            }
        }
    }
    
    let containerClaim;

    async function isClaimable() {
        if (isConnected && !isPermanentlyDisconnected && initialized) {
            if (isUnlocked) {
                const stakes = await contract.getStake(signerAddress);
                
                if (stakes.locked && Number(BigInt(stakes.lockEndTime)) != 0 && Date.now() > Number(BigInt(stakes.lockEndTime))) {
                    containerClaim = `
                        <p>You can claim!</p>
                    `;
                }
                else {
                    containerClaim = `
                        <p>Your stake is not claimable!</p>
                    `;
                }
            }
        }
    }

    async function claim() {
        if (isConnected && !isPermanentlyDisconnected && initialized) {
            if (isUnlocked) {
                const stakes = await contract.claimReward();
                alert(stakes);
            }
        }
    }
</script>

<header>
    <div class="navbar">
        <div class="title-block">
            <h1>Protected<span>.</span></h1>
        </div>
        <div class="connect-block">
            <button on:click={connectWallet} id="connect" class="class-button">{button}</button>
        </div>
    </div>
</header>
<main>
    <div class="connection">
        <div class="address">
            <p>{signerAddress}</p>
        </div>
    </div>
    <div class="infos-block">
        <div class="balance-block">
            <p><span>Apr</span> @ <span>5.78%</span></p>
            <h2>{tokenBalance} <span>LINK</span></h2>
            <p><span>{(tokenBalance * linkPrice).toFixed(2)}</span> USD</p>
        </div>
        <div class="interaction-block">
            <button id="borrow" class="class-button">Borrow Token</button>
        </div>
    </div>
    <div class="interface">
        <button on:click={getStake} class="class-button">Get Stake</button>
        <div contenteditable="false" bind:innerHTML={container} class="stakeBlock">
            
        </div>
        <button on:click={isClaimable} class="class-button">Check Claimable</button>
        <div contenteditable="false" bind:innerHTML={containerClaim} class="claimableBlock">

        </div>
        <button on:click={claim} class="class-button">Claim</button>
        <div class="group">
            <input bind:value={amount} type="text" name="amount" id="amount" placeholder="Amount" required>
            <label class="amount_label" for="amount">Amount</label>
        </div>
        <select bind:value={selected} name="duration" id="duration">
            <option value="7776000">90 days</option>
            <option value="15552000">180 days</option>
            <option value="23328000">270 days</option>
            <option value="31536000">365 days</option>
        </select>
        <button on:click={stakeToken} id="stake" class="class-button">Protect Token</button>
    </div>
</main>