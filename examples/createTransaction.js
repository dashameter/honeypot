import Dash from "dash";
import dashcore from "@dashevo/dashcore-lib";
import {
  createClientOpts,
  initIdentity,
  submitTransactionDocument,
} from "../lib/index.js";

const UTXO = {
  txId: "299456b08c94bd255ef017cdfb8169bd114ae805c19df9fd4cc8d0bcc42d47e7",
  outputIndex: 0,
  satoshis: 1000000,
};

const TO_OUTPUT = {
  address: "yWmaDGGSz1hFxXkVUR6n69E3FqfpQ5qgQn",
  amount: 100000,
};

const client = new Dash.Client(createClientOpts());

const createTransaction = async ({ txId, outputIndex, satoshis }, to) => {
  const account = await client.getWalletAccount();
  //   const address = account.getUnusedAddress();
  //   console.log("Unused address:", address.address);

  const identity = await initIdentity(client, account);

  const vault = (
    await client.platform.documents.get("honeypot.vault", {
      limit: 1,
    })
  )[0].toJSON();

  console.log("vault :>> ", vault);
  const vaultAddress = new dashcore.Address(vault.publicKeys, vault.threshold);
  console.log("Vault MultiSig Address: ", vaultAddress.toString());

  const utxo = {
    txId,
    outputIndex,
    address: vaultAddress.toString(),
    script: new dashcore.Script(vaultAddress).toHex(),
    satoshis,
  };

  const transaction = {
    vaultId: vault.$id,
    utxo,
    to,
  };

  submitTransactionDocument(client, identity, transaction);
};

createTransaction(UTXO, TO_OUTPUT)
  .catch((e) => console.error("Something went wrong:\n", e))
  .finally(() => client.disconnect());

// Handle wallet async errors
client.on("error", (error, context) => {
  console.error(`Client error: ${error.name}`);
  console.error(context);
});
