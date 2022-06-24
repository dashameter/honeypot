export const fetchSignatures = async function (client, { transactionId }) {
  const signatures = (
    await client.platform.documents.get("honeypot.signature", {
      limit: 10,
      where: [
        ["transactionId", "==", transactionId],
        ["$createdAt", ">", 0],
      ],
      orderBy: [["$createdAt", "desc"]],
    })
  ).map((tx) => tx.toJSON());
  return signatures;
};
