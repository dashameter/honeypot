import Dash from "dash";
import { createClientOpts, initIdentity } from "../lib/index.js";

const client = new Dash.Client(createClientOpts());

const registerContract = async () => {
  const { platform } = client;
  const account = await client.getWalletAccount();
  const identity = await initIdentity(client, account);

  // console.log("identity :>> ", identity);

  const contractDocuments = {
    vault: {
      type: "object",
      indices: [
        {
          name: "ownerId",
          properties: [{ $ownerId: "asc" }],
          unique: false,
        },
      ],
      properties: {
        threshold: { type: "integer" },
        identityIds: {
          type: "array",
          items: {
            type: "string",
          },
        },
        publicKeys: {
          type: "array",
          items: {
            type: "string",
          },
        },
      },
      additionalProperties: false,
    },
    transaction: {
      type: "object",
      indices: [
        {
          name: "ownerId",
          properties: [{ $ownerId: "asc" }],
          unique: false,
        },
      ],
      properties: {
        vaultId: { type: "string" },
        utxo: {
          type: "object",
          properties: {
            txId: { type: "string" },
            outputIndex: { type: "integer" },
            address: { type: "string" },
            script: { type: "string" },
            satoshis: { type: "integer" },
          },
          additionalProperties: false,
        },
        output: {
          type: "object",
          properties: {
            address: { type: "string" },
            amount: { type: "integer" },
          },
          additionalProperties: false,
        },
      },
      additionalProperties: false,
    },

    signature: {
      type: "object",
      indices: [
        {
          name: "ownerId",
          properties: [{ $ownerId: "asc" }],
          unique: false,
        },
        {
          name: "transactionId",
          properties: [{ transactionId: "asc" }],
          unique: false,
        },
      ],
      properties: {
        vaultId: { type: "string" },
        utxo: {
          type: "object",
          properties: {
            txId: { type: "string" },
            outputIndex: { type: "integer" },
            address: { type: "string" },
            script: { type: "string" },
            satoshis: { type: "integer" },
          },
          additionalProperties: false,
        },
        transactionId: { type: "string", maxLength: 63 },
        signature: {
          type: "object",
          properties: {
            publicKey: { type: "string" },
            prevTxId: { type: "string" },
            outputIndex: { type: "integer" },
            inputIndex: { type: "integer" },
            signature: { type: "string" },
            sigtype: { type: "integer" },
          },
          additionalProperties: false,
        },
      },
      additionalProperties: false,
    },
  };

  const contract = await platform.contracts.create(contractDocuments, identity);
  // console.dir({ contract });

  // Make sure contract passes validation checks
  await platform.dpp.initialize();
  const validationResult = await platform.dpp.dataContract.validate(contract);

  if (validationResult.isValid()) {
    // console.log("Validation passed, broadcasting contract..");
    // Sign and submit the data contract
    return platform.contracts.publish(contract, identity);
    // return true;
  }
  console.error(validationResult); // An array of detailed validation errors
  throw validationResult.errors[0];
};

registerContract()
  .then((d) => console.log(d.toJSON().dataContract.$id))
  .catch((e) => console.error("Something went wrong:\n", e))
  .finally(() => client.disconnect());
