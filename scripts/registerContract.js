import Dash from "dash";
import fs from "fs";
import { createClientOpts, getCachedIdentity } from "../lib/index.js";
import dotenv from "dotenv";
dotenv.config();

const client = new Dash.Client(createClientOpts(process.env.VITE_MNEMONIC1));

const registerContract = async () => {
  const { platform } = client;
  const account = await client.getWalletAccount();
  const identity = await getCachedIdentity(client, account);

  console.log("identityId :>> ", identity.getId().toString());

  const contractDocuments = {
    vault: {
      type: "object",
      indices: [
        {
          name: "ownerId",
          properties: [{ $ownerId: "asc" }],
          unique: false,
        },
        {
          name: "createdAt",
          properties: [{ $createdAt: "desc" }],
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
      required: ["$createdAt"],
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
        {
          name: "vaultIdCreatedAt",
          properties: [{ vaultId: "desc" }, { $createdAt: "desc" }],
          unique: false,
        },
      ],
      properties: {
        vaultId: { type: "string", maxLength: 63 },
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
      required: ["vaultId", "$createdAt"],
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
          name: "transactionIdCreatedAt",
          properties: [{ transactionId: "asc" }, { $createdAt: "desc" }],
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
      required: ["transactionId", "$createdAt"],
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
  .then((d) => {
    const contractId = d.toJSON().dataContract.$id;

    console.log("Registered contract with Id:", contractId);

    try {
      fs.appendFileSync(
        `.env.local`,
        `\nVITE_HONEYPOT_CONTRACTID=${contractId}\n`
      );

      console.log(
        `-> Appended 'VITE_HONEYPOT_CONTRACTID=${contractId} to .env.local`
      );
    } catch (e) {
      console.log(e);
      console.log(
        `Add 'VITE_HONEYPOT_CONTRACTID=${contractId}'' to your environment variables manually to share it with other dApps..`
      );
    }
  })
  .catch((e) => console.error("Something went wrong:\n", e))
  .finally(() => client.disconnect());
