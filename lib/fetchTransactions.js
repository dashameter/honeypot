export const fetchTransactions = async function (client, { vaultId }) {
  const transactions = (
    await client.platform.documents.get("honeypot.transaction", {
      limit: 10,
      where: [
        ["vaultId", "==", vaultId],
        ["$createdAt", ">", 0],
      ],
      orderBy: [["$createdAt", "desc"]],
    })
  ).map((tx) => tx.toJSON());
  return transactions;
};
