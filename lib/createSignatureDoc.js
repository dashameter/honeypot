import Dash from "dash";
const dashcore = Dash.Core;

// import dashcore from "@dashevo/dashcore-lib";

export const createSignatureDoc = ({ vaultDoc, transactionDoc, privateKey }) => {
  const vaultAddress = new dashcore.Address(
    vaultDoc.publicKeys,
    vaultDoc.threshold
  );

  console.log("vault :>> ", vaultDoc);
  console.log("transactionDoc :>> ", transactionDoc);

  const multiSigTx = new dashcore.Transaction()
    .from(transactionDoc.utxo, vaultDoc.publicKeys, vaultDoc.threshold)
    .to(transactionDoc.output.address, transactionDoc.output.amount)
    .change(vaultAddress);

  console.log("multiSigTx :>> ", multiSigTx);


  const pk = dashcore.PrivateKey(privateKey.toString());

  const signature = multiSigTx.getSignatures(pk)[0]; // TODO handle error case of not holding a valid privateKey

  const signatureDoc = {
    transactionId: transactionDoc.$id,
    signature: signature.toObject(),
  };

  return signatureDoc;
};
