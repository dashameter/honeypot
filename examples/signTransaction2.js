import dotenv from "dotenv";
dotenv.config();

import Dash from "dash";
import dashcore from "@dashevo/dashcore-lib";
import {
  createClientOpts,
  initIdentity,
  submitSignatureDocument,
} from "../lib/index.js";

const client = new Dash.Client(createClientOpts(process.env.MNEMONIC2));

const signTransaction = async ({}) => {
  const account = await client.getWalletAccount();
  //   const address = account.getUnusedAddress();
  //   console.log("Unused address:", address.address);

  const identity = await initIdentity(client, account);

  const transaction = (
    await client.platform.documents.get("honeypot.transaction", {
      limit: 1,
    })
  )[0].toJSON();

  console.log("transaction :>> ", transaction);
  console.log("transaction.utxo :>> ", transaction.utxo);

  const vault = (
    await client.platform.documents.get("honeypot.vault", {
      limit: 1,
      where: [["$id", "==", transaction.vaultId]],
    })
  )[0].toJSON();
  console.log("vault :>> ", vault);

  const vaultAddress = new dashcore.Address(vault.publicKeys, vault.threshold);
  console.log("Vault MultiSig Address: ", vaultAddress.toString());

  const multiSigTx = new dashcore.Transaction()
    .from(transaction.utxo, vault.publicKeys, vault.threshold)
    .to(transaction.output.address, transaction.output.amount)
    .change(vaultAddress);

  console.log("multiSigTx :>> ", multiSigTx);

  const privateKey = account.identities.getIdentityHDKeyByIndex(
    0,
    0
  ).privateKey;

  const signature = multiSigTx.getSignatures(privateKey)[0];
  console.log("signature.toObject", signature.toObject());

  submitSignatureDocument(client, identity, {
    transactionId: transaction.$id,
    signature: signature.toObject(),
  });
};

signTransaction({})
  .catch((e) => console.error("Something went wrong:\n", e))
  .finally(() => client.disconnect());

// Handle wallet async errors
client.on("error", (error, context) => {
  console.error(`Client error: ${error.name}`);
  console.error(context);
});
