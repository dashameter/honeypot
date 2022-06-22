import Dash from "dash";
const dashcore = Dash.Core;

export const createTransactionDoc = ({ vault, transactionArgs }) => {
  const vaultAddress = new dashcore.Address(vault.publicKeys, vault.threshold);

  // TODO assert vault.vaultAddress == vaultAddress

  const utxo = {
    txId: transactionArgs.input.txId,
    outputIndex: parseInt(transactionArgs.input.txId),
    address: vaultAddress.toString(),
    script: new dashcore.Script(vaultAddress).toHex(),
    satoshis: parseInt(transactionArgs.input.satoshis),
  };

  const transactionDoc = {
    vaultId: vault.id,
    utxo,
    to: {
      address: transactionArgs.output.address,
      amount: parseInt(transactionArgs.output.amount),
    },
  };

  return transactionDoc;
};
