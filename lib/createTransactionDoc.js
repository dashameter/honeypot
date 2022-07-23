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

  const transactionDoc = {
    vaultId: vault.id,
    network,
    utxos: utxosBuilt,
    to: {
      address: output.address,
      amount: parseInt(output.amount),
    },
  };

  console.log("transactionDoc :>> ", transactionDoc);

  return transactionDoc;
};
