// import "./style.css";
// import Dash from "dash";
import {
  createClientOpts,
  initIdentity,
  submitVaultDocument,
} from "./lib/index.js";
// @ts-ignore
import { Elm } from "./src/Main.elm";

// Init Elm App
const root = document.querySelector("#app div");
const app = Elm.Main.init({ node: root });

// Init Dash SDK
const dashcore = Dash.Core;
const client = new Dash.Client(createClientOpts());

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

app.ports.createVault.subscribe(function ({ threshold, identityIds }) {
  console.log("threshold :>> ", threshold);
  console.log("identityIds :>> ", identityIds);
  if (
    threshold > 0 &&
    threshold <= identityIds.length &&
    identityIds.length > 0
  )
    createVaultFromIdentities({ threshold, identityIds });
  else console.error("Bad Args");
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
  const vaults = (
    await client.platform.documents.get("honeypot.vault", {
      limit: 10,
    })
  ).map((vault) => vault.toJSON());
  console.log("vault :>> ", vaults);

  const vaultResponse = vaults.map((vault) => {
    const vaultAddress = new dashcore.Address(
      vault.publicKeys,
      vault.threshold
    ).toString();
    console.log("Vault MultiSig Address: ", vaultAddress);
    return {
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
  const identity = await initIdentity(client, account);
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

  console.log("vaultDocument :>> ", vaultDocument.toJSON());
};

// Handle wallet async errors
client.on("error", (error, context) => {
  console.error(`Client error: ${error.name}`);
  console.error(context);
});
