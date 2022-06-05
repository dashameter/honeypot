import Dash from "dash";
import dashcore from "@dashevo/dashcore-lib";
import {
  createClientOpts,
  initIdentity,
  submitVaultDocument,
} from "../lib/index.js";

const THRESHOLD = 2;
const SIGNER_IDENTITY_IDS = [
  "FaZJKgmkyGmEcx3ydL88VZAGUVHtbfWeVeihq2UMomSk",
  "5Uadpa6BDyynsBbxZpAQSpX8qdDv74Ru4mCYbofSjj46",
  "6DYRkA7hjFisNzSM9d7PHhZBZtypgZQWaxW2sTRJHqe3",
];

const client = new Dash.Client(createClientOpts());

const createVaultFromIdentities = async ({ threshold, identityIds }) => {
  const account = await client.getWalletAccount();
  //   const address = account.getUnusedAddress();
  //   console.log("Unused address:", address.address);

  const identity = await initIdentity(client, account);

  const signerIdentities = await Promise.all(
    identityIds.map((identityId) => client.platform.identities.get(identityId))
  );

  const publicKeys = signerIdentities.map((identity) => {
    return identity.publicKeys[0].data.toString("hex");
  });
  console.log("publicKeys :>> ", publicKeys);

  const vaultAddress = new dashcore.Address(publicKeys, threshold);
  console.log("Vault MultiSig Address: ", vaultAddress.toString());

  submitVaultDocument(client, identity, {
    threshold,
    identityIds,
    publicKeys,
  });
};

createVaultFromIdentities({
  threshold: 2,
  identityIds: SIGNER_IDENTITY_IDS,
})
  .catch((e) => console.error("Something went wrong:\n", e))
  .finally(() => client.disconnect());

// Handle wallet async errors
client.on("error", (error, context) => {
  console.error(`Client error: ${error.name}`);
  console.error(context);
});
