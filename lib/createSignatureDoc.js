import Dash from "dash";
const dashcore = Dash.Core;

// import dashcore from "@dashevo/dashcore-lib";

export const createSignatureDoc = ({
  vaultDoc,
  transactionDoc,
  privateKey,
}) => {
  const vaultAddress = new dashcore.Address(
    vaultDoc.publicKeys,
    vaultDoc.threshold,
    "testnet"
  );

  console.log("vault :>> ", vaultDoc);
  console.log("transactionDoc :>> ", transactionDoc);

  const multiSigTx = new dashcore.Transaction()
    .from(transactionDoc.utxos, vaultDoc.publicKeys, vaultDoc.threshold)
    .to(transactionDoc.output.address, transactionDoc.output.amount)
    .change(vaultAddress);

  console.log("multiSigTx :>> ", multiSigTx);

  const pk = dashcore.PrivateKey(privateKey.toString());

  const signature = multiSigTx.getSignatures(pk)[0]; // TODO handle error case of not holding a valid privateKey

  // const signatureIsValid = multiSigTx.applySignature(signature);

  const signatureIsValid = multiSigTx.isValidSignature(signature);

  console.log("signatureIsValid :>> ", signatureIsValid);

  multiSigTx.applySignature(signature);

  console.log("isFullySigned", multiSigTx.isFullySigned());

  const signatureDoc = {
    transactionId: transactionDoc.$id,
    signature: signature.toObject(),
  };

  return signatureDoc;
};
