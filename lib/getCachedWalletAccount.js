export const getCachedWalletAccount = async function (client) {
  if (client._account) return client._account;
  else {
    const account = await client.getWalletAccount();
    return account;
  }
};
