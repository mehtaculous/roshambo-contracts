# Roshambo

Just a friendly onchain game of Block Paper Scissors. Shoot!

<img src="images/roshambo.svg">

## How To Play

### `New Game`

> Creates a new game

- Start a new game by specifying a number of rounds, any wager amount in ether and submitting a commitment
- New games get added to the lobby of **Pending** games

### `Join Game`

> Joins a pending game

- Join any lobby game by matching the wager amount and submitting a commitment
- Once a game has begun, a new NFT gets minted to the smart contract
- The game then moves into the **Reveal** stage

### `Commit`

> Commits a player's choice

- The game moves into the **Commit** stage only once a round has been settled
- Both players will have **6969** blocks to submit their new commitment
- The game moves into the **Reveal** stage only once both players have committed their choice
- If either or both players fail to commit in time, the game will need to be manually settled

### `Reveal`

> Reveals a player's choice

- Both players will have **6969** blocks to reveal their committed choice
- Second player to reveal will also **Settle** that round, and possibly the game
- If either or both players fail to reveal in time, the game will need to be manually settled

### `Settle`

> Settles the results of a game

- This will either begin the next round, moving it back into the **Commit** stage OR a winner will be determined
- If the round does not get settled through **Reveal**, it can be settled manually by anyone
- Winner of the most rounds receives the NFT and their balance is updated with the game pot

## Setup

1. Clone repository

```
git@github.com:board-chain/roshambo.git
```

2. Create `.env` file in root

```
DEPLOYER_PRIVATE_KEY=
ETHERSCAN_API_KEY=
GOERLI_RPC_URL=
MAINNET_RPC_URL=
```

3. Install dependencies

```
npm ci
forge install
```

4. Run linter

```
npm run lint
```

5. Run all tests (Stack traces: `-vvvvv` | Gas report: `--gas-report`)

```
forge test --mc RoshamboTest
forge test --mc RoshamboTest -vvvvv
forge test --mc RoshamboTest --gas-report
```

6. Run individual tests

```
forge test --mt testNewGame
forge test --mt testJoinGame
forge test --mt testCommit
forge test --mt testReveal
forge test --mt testSettle
```

7. Deploy contracts

```
forge script script/Deploy.s.sol:Deploy --rpc-url $GOERLI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast
```

### Goerli Contracts

| Name       | Address                                                                                                                      |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `Recorder` | [0xC31Bb311ab46C159cFd823d3074cFe79B2Bb2341](https://goerli.etherscan.io/address/0xC31Bb311ab46C159cFd823d3074cFe79B2Bb2341) |
| `Renderer` | [0x5b261f2b051AD1EbBEdB6f85699C59C864e25F87](https://goerli.etherscan.io/address/0x5b261f2b051AD1EbBEdB6f85699C59C864e25F87) |
| `Roshambo` | [0xde339cc3dB6b8c4e6eFb77f9ebf3Dae2a97D7993](https://goerli.etherscan.io/address/0xde339cc3dB6b8c4e6eFb77f9ebf3Dae2a97D7993) |

### Gas Report

| src/Roshambo.sol |                 |         |         |         |         |
| ---------------- | --------------- | ------- | ------- | ------- | ------- |
| Deployment Cost  | Deployment Size |         |         |         |         |
| 5657177          | 28820           |         |         |         |         |
| Function Name    | min             | avg     | median  | max     | # calls |
| cancel           | 1003            | 3578    | 1143    | 8588    | 3       |
| commit           | 710             | 22991   | 25988   | 28660   | 25      |
| joinGame         | 897             | 86095   | 98963   | 98963   | 31      |
| newGame          | 2700            | 100117  | 106461  | 106461  | 37      |
| reveal           | 1000            | 33559   | 7171    | 266931  | 53      |
| setBeneficiary   | 7578            | 7578    | 7578    | 7578    | 1       |
| setRake          | 719             | 902     | 719     | 7519    | 37      |
| settle           | 1621            | 13421   | 5885    | 53185   | 6       |
| tokenURI         | 1655499         | 1655499 | 1655499 | 1655499 | 1       |
| withdraw         | 2621            | 8116    | 7704    | 10828   | 11      |
