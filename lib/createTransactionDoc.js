import Dash from "dash";
const dashcore = Dash.Core;

export const createTransactionDoc = ({ vault, utxos, output, network }) => {
  const vaultAddress = new dashcore.Address(
    vault.publicKeys,
    vault.threshold,
    network
  );

  // TODO assert vault.vaultAddress == vaultAddress

  const utxosBuilt = utxos.map((utxo) => {
    return {
      txId: utxo.txid,
      outputIndex: parseInt(utxo.vout),
      address: utxo.address, // or address: vaultAddress.toString(),
      script: utxo.scriptPubKey, // or script: new dashcore.Script(vaultAddress).toHex(),
      satoshis: parseInt(utxo.satoshis),
    };
  });

  // TODO remove static dashmate test
  // const utxoBuilt = {
  //   txId: "305881d8edf5a4d7175a78ab9b573a235aa0ea1c10a9de7e7ea26d6f8966f37f", //utxo.txid,
  //   outputIndex: 0, //parseInt(utxo.vout),
  //   address: "yWmaDGGSz1hFxXkVUR6n69E3FqfpQ5qgQn", // utxo.address, // or address: vaultAddress.toString(),
  //   script: new dashcore.Script("91DzvuNvNgP2p5KenQNYBSyivDL848fhzG").toHex(), //utxo.scriptPubKey, // or script: new dashcore.Script(vaultAddress).toHex(),
  //   satoshis: 100000, //parseInt(utxo.satoshis),
  // };

  const transactionDoc = {
    vaultId: vault.id,
    network,
    utxos: utxosBuilt,
    to: {
      address: output.address,
      amount: parseInt(output.amount),
    },
  };

  return transactionDoc;
};
