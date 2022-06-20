export const submitVaultDocument = async (
  client,
  identity,
  { threshold, identityIds, publicKeys }
) => {
  const { platform } = client;

  const docProperties = {
    threshold,
    identityIds,
    publicKeys,
  };
  console.log("docProperties :>> ", docProperties);
  // Create the note document
  const vaultDocument = await platform.documents.create(
    "honeypot.vault",
    identity,
    docProperties
  );

  const documentBatch = {
    create: [vaultDocument], // Document(s) to create
    replace: [], // Document(s) to update
    delete: [], // Document(s) to delete
  };
  console.log("documentBatch :>> ", documentBatch);
  // Sign and submit the document(s)
  const res = await platform.documents.broadcast(documentBatch, identity);
  console.log("res :>> ", res);
  return res;
};
