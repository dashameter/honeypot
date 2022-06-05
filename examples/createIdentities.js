import Dash from "dash";
import { createClientOpts, initIdentity } from "../lib/index.js";

const SIGNER_MNEMONICS = [
  process.env.MNEMONIC1,
  process.env.MNEMONIC2,
  process.env.MNEMONIC3,
];

const createIdentities = function (mnemonics) {
  for (let i = 0; i < mnemonics.length; i++) {
    const client = new Dash.Client(createClientOpts(mnemonics[i]));

    const createIdentity = async function () {
      const account = await client.getWalletAccount();
      const address = account.getUnusedAddress();
      console.log("Unused address:", address.address);

      const identity = await initIdentity(client, account);

      console.log(i, identity.id.toString());
    };

    createIdentity()
      .catch((e) => console.error("Something went wrong:\n", e))
      .finally(() => client.disconnect());

    // Handle wallet async errors
    client.on("error", (error, context) => {
      console.error(`Client error: ${error.name}`);
      console.error(context);
    });
  }
};

createIdentities(SIGNER_MNEMONICS);
