import Dash from "dash";
import assert from "assert";
import TransactionSignature from "@dashevo/dashcore-lib/lib/transaction/signature.js";
import dashcore from "@dashevo/dashcore-lib";
import {
  createClientOpts,
  initIdentity,
  submitSignatureDocument,
} from "../lib/index.js";

const client = new Dash.Client(createClientOpts());

const executeTransaction = async ({}) => {
  const account = await client.getWalletAccount();

  const identity = await initIdentity(client, account);

  const transaction = (
    await client.platform.documents.get("honeypot.transaction", {
      limit: 1,
    })
  )[0].toJSON();

  console.log("transaction :>> ", transaction);

  const signatures = (
    await client.platform.documents.get("honeypot.signature", {
      where: [["transactionId", "==", transaction.$id]],
    })
  ).map((x) => x.toJSON());

  console.log("signatures :>> ", signatures);

  const vault = (
    await client.platform.documents.get("honeypot.vault", {
      limit: 1,
      where: [["$id", "==", transaction.vaultId]],
    })
  )[0].toJSON();

  console.log("vault :>> ", vault);

  const vaultAddress = new dashcore.Address(vault.publicKeys, vault.threshold);
  console.log("Vault MultiSig Address: ", vaultAddress.toString());

  var multiSigTx = new dashcore.Transaction()
    .from(transaction.utxo, vault.publicKeys, vault.threshold)
    .to(transaction.output.address, transaction.output.amount)
    .change(vaultAddress);

  console.log("multiSigTx :>> ", multiSigTx);

  const txSignatures = signatures.map((sig) =>
    TransactionSignature.fromObject(sig.signature)
  );
  console.log("txSignatures:>> ", txSignatures);

  assert(multiSigTx.isValidSignature(txSignatures[0]));
  multiSigTx.applySignature(txSignatures[0]);

  assert(multiSigTx.isValidSignature(txSignatures[1]));
  multiSigTx.applySignature(txSignatures[1]);

  console.log(multiSigTx.isFullySigned());
  console.log(multiSigTx.toString());
  console.log("multiSigTx :>> ", multiSigTx);

  const txId = await account.broadcastTransaction(multiSigTx);
  console.log("txId :>> ", txId);
};

executeTransaction({})
  .catch((e) => console.error("Something went wrong:\n", e))
  .finally(() => client.disconnect());

// Handle wallet async errors
client.on("error", (error, context) => {
  console.error(`Client error: ${error.name}`);
  console.error(context);
});
