// import "./style.css";
// import Dash from "dash";
import {
  createClientOpts,
  getCachedIdentity,
  submitVaultDocument,
  getCachedWalletAccount,
  createTransactionDoc,
  createSignatureDoc,
  submitTransactionDocument,
  submitSignatureDocument,
  fetchTransactions,
  fetchSignatures,
} from "./lib/index.js";
// @ts-ignore
import { Elm } from "./src/Main.elm";

// Init Elm App
const root = document.querySelector("#app div");
const app = Elm.Main.init({ node: root });

// Init Dash SDK
const dashcore = Dash.Core;
// import TransactionSignature from "@dashevo/dashcore-lib/lib/transaction/signature.js";
console.log("dashcore :>> ", dashcore);
const TransactionSignature = dashcore.Transaction.Signature;
console.log("TransactionSignature :>> ", TransactionSignature);
const client = new Dash.Client(createClientOpts());
// Init Wallet Account so it's available
(async function () {
  client._account = await getCachedWalletAccount(client);
  client._identity = await getCachedIdentity(client, client._account);
})();
//7XLWySM6uir3oP2UEvhTAXtts3U74ihWvK
// Init Data
fetchVaults();

/**
 * @typedef PublicKey
 * @type {object}
 * @property {string} identityId - The Dash IdentityId.
 * @property {string} name - The DPNS Label.
 * @property {string} publicKey - The Identity's PublicKey.
 */

/**
 * @typedef PublicKeys
 * @type {object}
 * @property {string} identityId - The Dash IdentityId.
 * @property {object} PublicKey - The PublicKey Object.
 */

/** @type {PublicKeys|{}} */
const PublicKeys = {};

let Vaults = [];
let Transactions = [];
let Signatures = [];

app.ports.executeTransaction.subscribe(async function ({ transactionId }) {
  const account = await getCachedWalletAccount(client);

  const transactionDoc = Transactions.find((tx) => tx.$id === transactionId);
  const vaultDoc = Vaults.find((vault) => vault.$id === transactionDoc.vaultId);

  // TODO remove and have signatures already in cache
  await updateSignatures({ transactionIds: [transactionId] });

  const signatureDocs = Signatures.filter(
    (sig) => sig.transactionId === transactionId
  );

  console.log("transactionDoc :>> ", transactionDoc);
  console.log("vaultDoc :>> ", vaultDoc);
  console.log("signatureDocs :>> ", signatureDocs);

  const vaultAddress = new dashcore.Address(
    vaultDoc.publicKeys,
    vaultDoc.threshold
  );

  const multiSigTx = new dashcore.Transaction()
    .from(transactionDoc.utxo, vaultDoc.publicKeys, vaultDoc.threshold)
    .to(transactionDoc.output.address, transactionDoc.output.amount)
    .change(vaultAddress);

  console.log("multiSigTx :>> ", multiSigTx);

  const txSignatures = signatureDocs.map((sig) =>
    TransactionSignature.fromObject(sig.signature)
  );
  console.log("txSignatures:>> ", txSignatures);

  // assert(multiSigTx.isValidSignature(txSignatures[0]));
  multiSigTx.applySignature(txSignatures[0]);

  // assert(multiSigTx.isValidSignature(txSignatures[1]));
  // multiSigTx.applySignature(txSignatures[1]);

  console.log("isFullySigned", multiSigTx.isFullySigned());
  console.log("multiSigTx", multiSigTx.toString());
  console.log("multiSigTx :>> ", multiSigTx);

  const txId = await account.broadcastTransaction(multiSigTx);
  console.log("txId :>> ", txId);
});

app.ports.signTransaction.subscribe(async function ({ transactionId }) {
  const account = await getCachedWalletAccount(client);
  const identity = await getCachedIdentity(client, account);
  const privateKey = account.identities
    .getIdentityHDKeyByIndex(0, 0)
    .privateKey.toString();

  const transactionDoc = Transactions.find((tx) => tx.$id === transactionId);
  const vaultDoc = Vaults.find((vault) => vault.$id === transactionDoc.vaultId);

  const signatureDoc = createSignatureDoc({
    vaultDoc,
    transactionDoc,
    privateKey,
  });
  console.log("signatureDoc :>> ", signatureDoc);

  const result = await submitSignatureDocument(client, identity, signatureDoc);
  console.log("result :>> ", result);
  updateSignatures({ transactionIds: [transactionId] });
});
async function updateSignatures({ transactionIds }) {
  const promises = transactionIds.map((transactionId) =>
    fetchSignatures(client, { transactionId })
  );
  const signatures = (await Promise.all(promises)).flat().map((s) => {
    return { ...s, id: s.$id };
  });

  console.log("signatures :>> ", signatures);

  // Keep a local cache of transaction docs
  Signatures = signatures;

  app.ports.getSignatures.send(signatures);
  return;
}
app.ports.createTransaction.subscribe(async function ({
  vault,
  transactionArgs,
}) {
  const account = await getCachedWalletAccount(client);
  const identity = await getCachedIdentity(client, account);

  console.log("vault :>> ", vault);
  console.log("PublicKeys :>> ", PublicKeys);
  console.log("transactionArgs :>> ", transactionArgs);

  const transactionDoc = createTransactionDoc({ vault, transactionArgs });
  const result = await submitTransactionDocument(
    client,
    identity,
    transactionDoc
  );
  console.log("result :>> ", result.toJSON());
  // TODO update by vaultId
  updateTransactions({ vaultId: vault.id });
});

app.ports.fetchTransactions.subscribe(async function ({ vaultId }) {
  console.log("vaultId :>> ", vaultId);
  updateTransactions({ vaultId });
});

async function updateTransactions({ vaultId }) {
  const transactions = (await fetchTransactions(client, { vaultId })).map(
    (t) => {
      return { ...t, id: t.$id };
    }
  );
  console.log("transactions :>> ", transactions);

  // Keep a local cache of transaction docs
  Transactions = transactions;

  const transactionIds = transactions.map((tx) => tx.$id);
  console.log("transactionIds :>> ", transactionIds);

  updateSignatures({ transactionIds });

  app.ports.getTransactionList.send(transactions);
}

app.ports.createVault.subscribe(async function ({ threshold, identityIds }) {
  console.log("threshold :>> ", threshold);
  console.log("identityIds :>> ", identityIds);
  if (
    threshold > 0 &&
    threshold <= identityIds.length &&
    identityIds.length > 0
  ) {
    const result = await createVaultFromIdentities({
      threshold,
      identityIds,
    });

    const vaultId = result.transitions[0].$id;
    app.ports.getCreatedVaultId.send(vaultId);

    // Refresh vaults list
    fetchVaults();
  } else console.error("Bad Args");
});

app.ports.searchDashNames.subscribe(async function (searchDashName) {
  console.log("searchDashName :>> ", searchDashName);

  if (searchDashName === "")
    // No search str -> return empty results
    app.ports.getdashNameResults.send([]);
  else {
    const results = (
      await client.platform.names.search(searchDashName, "dash")
    ).map((dpns) => dpns.toJSON());

    console.log("results :>> ", results);

    const dashNameResults = results.map((user) => {
      return { name: user.label, identityId: user.$ownerId };
    });

    // TODO resolve Identity and store publicKey in global object

    console.log("dashNameResults :>> ", dashNameResults);

    // Cache the public Keys for the fetched Dash names
    dashNameResults.map(fetchPublicKeyForDashName);

    // Send resultDashNames back to elm
    app.ports.getdashNameResults.send(dashNameResults);
  }
});

async function fetchPublicKeyForDashName({ identityId, name }) {
  const identity = await client.platform.identities.get(identityId);

  const publicKey = identity.publicKeys[0].data.toString("hex");

  PublicKeys[identityId] = { identityId, name, publicKey };

  console.log("PublicKeys :>> ", PublicKeys);
  return;
}

async function fetchVaults() {
  const account = await client.getWalletAccount();
  const identityId = await account.identities.getIdentityIds()[0];
  console.log("identityId :>> ", identityId);

  const vaults = (
    await client.platform.documents.get("honeypot.vault", {
      limit: 10,
      where: [["$createdAt", ">", 0]],
      orderBy: [["$createdAt", "desc"]],
    })
  ).map((vault) => vault.toJSON());
  console.log("vault :>> ", vaults);

  // Keep a local cache of vault docs
  Vaults = vaults;

  const vaultResponse = vaults.map((vault) => {
    const vaultAddress = new dashcore.Address(
      vault.publicKeys,
      vault.threshold
    ).toString();
    console.log("Vault MultiSig Address: ", vaultAddress);
    return {
      id: vault.$id,
      threshold: vault.threshold,
      identityIds: vault.identityIds,
      publicKeys: vault.publicKeys,
      vaultAddress,
    };
  });
  console.log("vaultResponse :>> ", vaultResponse);
  // Send vaults back to elm
  app.ports.getVaults.send(vaultResponse);
}

const createVaultFromIdentities = async ({ threshold, identityIds }) => {
  const account = await client.getWalletAccount();
  const address = account.getUnusedAddress();
  console.log("Unused address:", address.address);
  const identity = await getCachedIdentity(client, account);
  const signerIdentities = await Promise.all(
    identityIds.map((identityId) => client.platform.identities.get(identityId))
  );
  const publicKeys = signerIdentities.map((identity) => {
    console.log("identity :>> ", identity);
    return identity.publicKeys[0].data.toString("hex");
  });
  console.log("publicKeys :>> ", publicKeys);
  const vaultAddress = new dashcore.Address(publicKeys, threshold);
  console.log("Vault MultiSig Address: ", vaultAddress.toString());
  const vaultDocument = await submitVaultDocument(client, identity, {
    threshold,
    identityIds,
    publicKeys,
  });

  return vaultDocument.toJSON();
  // TODO send vaultDocument.toJSON().transitions[0].$id back to elm to display txs for this vault
};

// Handle wallet async errors
client.on("error", (error, context) => {
  console.error(`Client error: ${error.name}`);
  console.error(context);
});
