# Stable Coin (DeFi)

it is a decentralized stable coin contract that allows users to deposit collateral, mint and burn DSC (a stablecoin), and manage liquidation risks. The contract allows users to deposit ERC20 tokens as collateral, mint DSC tokens against it, and redeem or liquidate collateral based on their health factor.

## Features

- **Deposit Collateral**: Users can deposit ERC20 tokens as collateral.
- **Mint DSC**: Users can mint DSC stablecoins by providing collateral.
- **Redeem Collateral**: Users can redeem their collateral after burning DSC tokens.
- **Health Factor**: The system ensures that users maintain a healthy collateral-to-debt ratio (health factor).
- **Liquidation**: Users with a low health factor can be liquidated, allowing others to take their collateral.

## Key Concepts

- **Health Factor**: A value that determines the safety of the user’s collateral position. If it falls below a threshold, liquidation can occur.
- **Collateral**: ERC20 tokens used as collateral for minting DSC.
- **DSC**: A stablecoin minted by the contract based on the collateral deposited by users.

## Installation

```bash
git clone https://github.com/mohamed-Decentralized/stable-coin-foundry.git
cd stable-coin-foundry
forge install
forge build
```