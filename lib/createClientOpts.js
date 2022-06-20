// import dotenv from "dotenv";
// dotenv.config();

// import * as NodeForage from "nodeforage";
// const nodeforage = new NodeForage({ name: "walletdb" });

// console.log(process.env); // remove this after you've confirmed it working

// if (!import.meta.env) {
//   import.meta.env = process.env;
// }

export const createClientOpts = function (
  mnemonic = import.meta.env.VITE_MNEMONIC1
) {
  if (typeof process !== "undefined" && process.env)
    import.meta.env = process.env;

  const clientOpts = {
    network: "testnet",
    wallet: {
      mnemonic,
      // adapter: nodeforage,
    },
    apps: {
      honeypot: {
        contractId: import.meta.env
          ? import.meta.env.VITE_HONEYPOT_CONTRACTID
          : "",
      },
    },
  };

  if (import.meta.env.VITE_LOCALNETWORK)
    clientOpts.dapiAddresses = ["127.0.0.1:3000"];

  return clientOpts;
};
