export const submitTransactionDocument = async (
  client,
  identity,
  { vaultId, utxos, to, network }
) => {
  const { platform } = client;

  const docProperties = {
    vaultId,
    utxos,
    output: to,
    network,
  };

  console.log("docProperties :>> ", docProperties);

  // Create the note document
  const transactionDocument = await platform.documents.create(
    "honeypot.transaction",
    identity,
    docProperties
  );

  const documentBatch = {
    create: [transactionDocument], // Document(s) to create
    replace: [], // Document(s) to update
    delete: [], // Document(s) to delete
  };
  console.log("documentBatch :>> ", documentBatch);
  // Sign and submit the document(s)
  const res = await platform.documents.broadcast(documentBatch, identity);
  console.log("res :>> ", res);
  return res;
};
