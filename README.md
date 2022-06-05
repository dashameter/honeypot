# HoneyPot

a MultiSig Wallet for Dash powered by Platform

_WIP: The lib is built out using example scripts. Once the SDK compiles issue-free for the browser, the lib will be connected to a webUI_

## Usage

To run against a local dashmate network add `LOCALNETWORK=true` to `.env`

1. Add mnemonics to `.env`
2. Run `node examples/createIdentities.js`
3. Run `node scripts/registerContract.js`
4. Add the `contractId` to `.env`
5. Add the `identityIds`to `examples/createVaultFromIdentities.js`
6. Run `node examples/createVaultFromIdentities.js`
7. Send some tDash to the vaultAddress
8. Add the vaultAddress `utxo` to `examples/createTransaction.js`
9. Run `node examples/createTransaction.js`
10. Run `node examples/signTransaction.js`
11. Run `node examples/signTransaction2.js`
12. Run `node examples/executeTransaction.js`

## Todo

- [ ] Create webUI
- [ ] Add advanced indices to filter out spam signatures
- [ ] Optimize contracts by using byte arrays and removing recoverable data from document types
- [ ] Support multiple signed inputs
