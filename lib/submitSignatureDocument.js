export const submitSignatureDocument = async (
  client,
  identity,
  { transactionId, signature }
) => {
  const { platform } = client;

  const docProperties = {
    transactionId,
    signature,
  };

  console.log("docProperties :>> ", docProperties);

  // Create the document
  const signatureDocument = await platform.documents.create(
    "honeypot.signature",
    identity,
    docProperties
  );

  const documentBatch = {
    create: [signatureDocument], // Document(s) to create
    replace: [], // Document(s) to update
    delete: [], // Document(s) to delete
  };
  console.log("documentBatch :>> ", documentBatch);
  // Sign and submit the document(s)
  const res = await platform.documents.broadcast(documentBatch, identity);
  console.log("res :>> ", res);
  return res;
};
