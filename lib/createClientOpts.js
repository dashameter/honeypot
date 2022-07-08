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
  // This enables running in node and in vite
  if (typeof process !== "undefined" && process.env)
    import.meta.env = process.env;

  const clientOpts = {
    network: import.meta.env.VITE_NETWORK,
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

  if (import.meta.env.VITE_DAPIADDRESSES)
    clientOpts.dapiAddresses = JSON.parse(import.meta.env.VITE_DAPIADDRESSES);

  console.log("clientOpts :>> ", clientOpts);

  return clientOpts;
};
