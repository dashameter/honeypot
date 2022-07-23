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
import axios from "axios";

// Init Elm App
const root = document.querySelector("#app div");
const app = Elm.Main.init({
  node: root,
  flags: {
    apiHostTestnet: import.meta.env.VITE_INSIGHT_API_URL_TESTNET,
    apiHostMainnet: import.meta.env.VITE_INSIGHT_API_URL_MAINNET,
    network: import.meta.env.VITE_NETWORK,
  },
});

console.log("import.meta.env.MODE :>> ", import.meta.env.MODE);
console.log("import.meta.env.VITE_NETWORK :>> ", import.meta.env.VITE_NETWORK);
console.log(
  "import.meta.env.VITE_HONEYPOT_CONTRACTID :>> ",
  import.meta.env.VITE_HONEYPOT_CONTRACTID
);
// Init Dash SDK
const dashcore = Dash.Core;
// import TransactionSignature from "@dashevo/dashcore-lib/lib/transaction/signature.js";
const TransactionSignature = dashcore.Transaction.Signature;
const client = new Dash.Client(createClientOpts());
// Init Wallet Account so it's available
(async function () {
  client._account = await getCachedWalletAccount(client);
  client._identity = await getCachedIdentity(client, client._account);
})();
//7XLWySM6uir3oP2UEvhTAXtts3U74ihWvK
// Init Data
// fetchVaults({ network: "testnet" }); // TODO call initial fetch from ELM, supplying the chosen L1 Network

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

app.ports.executeTransaction.subscribe(async function ({
  transactionId,
  network,
}) {
  const apiHost = import.meta.env.VITE_INSIGHT_API_URL_TESTNET; // TODO support switching to mainnet
  const account = await getCachedWalletAccount(client);

  const transactionDoc = Transactions.find((tx) => tx.$id === transactionId);
  const vaultDoc = Vaults.find((vault) => vault.$id === transactionDoc.vaultId);

  // TODO remove and have signatures already in cache
  await updateSignatures({ transactionIds: [transactionId] });

  const signatureDocs = Signatures.filter(
    (sig) => sig.transactionId === transactionId
  );

  // console.log("transactionDoc :>> ", transactionDoc);
  // console.log("vaultDoc :>> ", vaultDoc);
  // console.log("signatureDocs :>> ", signatureDocs);

  const vaultAddress = new dashcore.Address(
    vaultDoc.publicKeys,
    vaultDoc.threshold,
    network
  );

  const multiSigTx = new dashcore.Transaction()
    .from(transactionDoc.utxos, vaultDoc.publicKeys, vaultDoc.threshold)
    .to(transactionDoc.output.address, transactionDoc.output.amount)
    .change(vaultAddress);

  // console.log("multiSigTx :>> ", multiSigTx);

  const txSignatures = signatureDocs.map((sig) =>
    TransactionSignature.fromObject(sig.signature)
  );
  // console.log("txSignatures:>> ", txSignatures);

  // assert(multiSigTx.isValidSignature(txSignatures[0]));
  multiSigTx.applySignature(txSignatures[0]);

  // assert(multiSigTx.isValidSignature(txSignatures[1]));
  // multiSigTx.applySignature(txSignatures[1]);

  // console.log("isFullySigned", multiSigTx.isFullySigned());
  // console.log("multiSigTx", multiSigTx.toString());
  // console.log("multiSigTx :>> ", multiSigTx);

  axios
    .post(
      apiHost + "/tx/send",
      {
        rawtx: multiSigTx.toString(),
      }
      //  {headers: {"Content-Type": "text/plain"}}
    )
    .then(function (response) {
      console.log(response.data);
    })
    .catch(function (error) {
      console.log(error.response.data);
    });

  // TODO use account.broadcastTransaction once utxo bug in SDK is fixed
  // const txId = await account.broadcastTransaction(multiSigTx);
  // console.log("txId :>> ", txId);
});

app.ports.signTransaction.subscribe(async function ({
  transactionId,
  network,
}) {
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
    network,
  });
  // console.log("signatureDoc :>> ", signatureDoc);

  const result = await submitSignatureDocument(client, identity, signatureDoc);
  // console.log("result :>> ", result);
  updateSignatures({ transactionIds: [transactionId] });
});
async function updateSignatures({ transactionIds }) {
  const promises = transactionIds.map((transactionId) =>
    fetchSignatures(client, { transactionId })
  );
  const signatures = (await Promise.all(promises)).flat().map((s) => {
    return { ...s, id: s.$id };
  });

  // console.log("signatures :>> ", signatures);

  // Keep a local cache of transaction docs
  Signatures = signatures;

  app.ports.getSignatures.send(signatures);
  return;
}
app.ports.createTransaction.subscribe(async function ({
  vault,
  utxos,
  output,
  network,
}) {
  const account = await getCachedWalletAccount(client);
  const identity = await getCachedIdentity(client, account);

  // console.log("vault :>> ", vault);
  // console.log("utxos :>> ", utxos);
  // console.log("output :>> ", output);

  const transactionDoc = createTransactionDoc({
    vault,
    utxos,
    output,
    network,
  });

  const result = await submitTransactionDocument(
    client,
    identity,
    transactionDoc
  );

  updateTransactions({ vaultId: vault.id, network });
});

app.ports.fetchTransactions.subscribe(async function ({
  vaultAddress,
  vaultId,
  network,
}) {
  // console.log("vaultId :>> ", vaultId);
  updateTransactions({ vaultAddress, vaultId, network });
});

async function updateTransactions({ vaultAddress, vaultId, network }) {
  const transactions = (
    await fetchTransactions(client, { vaultId, network })
  ).map((t) => {
    return { ...t, id: t.$id };
  });
  // console.log("transactions :>> ", transactions);

  // Keep a local cache of transaction docs
  Transactions = transactions;

  const transactionIds = transactions.map((tx) => tx.$id);
  // console.log("transactionIds :>> ", transactionIds);

  updateSignatures({ transactionIds });

  console.log("{ vaultAddress, transactions } :>> ", {
    vaultAddress,
    transactions,
  });

  app.ports.getTransactionQueue.send({ vaultAddress, transactions });
}

app.ports.createVault.subscribe(async function ({
  threshold,
  identityIds,
  network,
}) {
  // console.log("threshold :>> ", threshold);
  // console.log("identityIds :>> ", identityIds);
  if (
    threshold > 0 &&
    threshold <= identityIds.length &&
    identityIds.length > 0
  ) {
    const result = await createVaultFromIdentities({
      threshold,
      identityIds,
      network,
    });

    const vaultId = result.transitions[0].$id;
    app.ports.getCreatedVaultId.send(vaultId);

    // Refresh vaults list
    // fetchVaults({ network });
  } else console.error("Bad Args");
});

app.ports.fetchVaults.subscribe(async function ({ network }) {
  // console.log("fetchVaults.subscribe network :>> ", network);
  fetchVaults({ network });
});

app.ports.searchDashNames.subscribe(async function (searchDashName) {
  // console.log("searchDashName :>> ", searchDashName);

  if (searchDashName === "")
    // No search str -> return empty results
    app.ports.getdashNameResults.send([]);
  else {
    const results = (
      await client.platform.names.search(searchDashName, "dash")
    ).map((dpns) => dpns.toJSON());

    // console.log("results :>> ", results);

    const dashNameResults = results.map((user) => {
      return { name: user.label, identityId: user.$ownerId };
    });

    // TODO resolve Identity and store publicKey in global object

    // console.log("dashNameResults :>> ", dashNameResults);

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

  // console.log("PublicKeys :>> ", PublicKeys);
  return;
}

async function fetchVaults({ network }) {
  const account = await client.getWalletAccount();
  const identityId = await account.identities.getIdentityIds()[0];
  // console.log("identityId :>> ", identityId);

  const vaults = (
    await client.platform.documents.get("honeypot.vault", {
      limit: 10,
      where: [["$createdAt", ">", 0]],
      orderBy: [["$createdAt", "desc"]],
    })
  ).map((vault) => vault.toJSON());
  // console.log("vault :>> ", vaults);

  // Keep a local cache of vault docs
  Vaults = vaults;

  const vaultResponse = vaults.map((vault) => {
    const vaultAddress = new dashcore.Address(
      vault.publicKeys,
      vault.threshold,
      network
    ).toString();
    // console.log("Vault MultiSig Address: ", vaultAddress);
    return {
      id: vault.$id,
      threshold: vault.threshold,
      identityIds: vault.identityIds,
      publicKeys: vault.publicKeys,
      vaultAddress,
    };
  });
  // console.log("vaultResponse :>> ", vaultResponse);
  // Send vaults back to elm
  app.ports.getVaults.send(vaultResponse);
}

const createVaultFromIdentities = async ({
  threshold,
  identityIds,
  network,
}) => {
  const account = await client.getWalletAccount();
  const address = account.getUnusedAddress();
  // console.log("Unused address:", address.address);
  const identity = await getCachedIdentity(client, account);
  const signerIdentities = await Promise.all(
    identityIds.map((identityId) => client.platform.identities.get(identityId))
  );
  const publicKeys = signerIdentities.map((identity) => {
    // console.log("identity :>> ", identity);
    return identity.publicKeys[0].data.toString("hex");
  });
  // console.log("publicKeys :>> ", publicKeys);
  const vaultAddress = new dashcore.Address(publicKeys, threshold, network);
  // console.log("Vault MultiSig Address: ", vaultAddress.toString());
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

// DashClient Ports
//
app.ports.dashClient.subscribe(async function ({ cmd, payload }) {
  const Address = dashcore.Address;
  // console.log("cmd, payload:>> ", cmd, payload);

  const resolveIdentities = async (identityIds) => {
    identityIds.map((identityId) => {
      client.platform.names
        .resolveByRecord("dashUniqueIdentityId", identityId)
        .then((results) => {
          if (results.length > 0) {
            const result = results[0].toJSON();
            app.ports.getDashClient.send({ cmd: "resolveIdentities", result });
          }
        });
    });
  };
  switch (cmd) {
    case "resolveIdentities":
      resolveIdentities(payload);
      break;

    case "address.isValid":
      app.ports.getDashClient.send({
        cmd: "address.isValid",
        result: Address.isValid(payload[0], payload[1]),
      });
      break;

    default: //Default will perform if all case’s fail
      console.error("Unknown DashClient Cmd.", cmd);
      break;
  }
});
