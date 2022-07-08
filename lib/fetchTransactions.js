export const fetchTransactions = async function (client, { vaultId, network }) {
  const transactions = (
    await client.platform.documents.get("honeypot.transaction", {
      limit: 10,
      where: [
        ["network", "==", network],
        ["vaultId", "==", vaultId],
        ["$createdAt", ">", 0],
      ],
      orderBy: [["$createdAt", "desc"]],
    })
  ).map((tx) => tx.toJSON());
  return transactions;
};
