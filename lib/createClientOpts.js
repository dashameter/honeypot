import dotenv from "dotenv";
dotenv.config();

// import * as NodeForage from "nodeforage";
// const nodeforage = new NodeForage({ name: "walletdb" });

// console.log(process.env); // remove this after you've confirmed it working

export const createClientOpts = function (mnemonic = process.env.MNEMONIC1) {
  const clientOpts = {
    network: "testnet",
    wallet: {
      mnemonic,
      // adapter: nodeforage,
    },
    apps: {
      honeypot: {
        contractId: process.env.HONEYPOT_CONTRACTID,
      },
    },
  };

  if (process.env.LOCALNETWORK) clientOpts.dapiAddresses = ["127.0.0.1:3000"];

  return clientOpts;
};
