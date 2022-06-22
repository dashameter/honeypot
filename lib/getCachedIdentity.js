export const getCachedIdentity = async function (client, account) {
  if (client._identity) return client._identity;
  else {
    let identity;
    let identityId = await account.identities.getIdentityIds()[0];
    console.log("identityId :>> ", identityId);
    if (identityId) identity = await client.platform.identities.get(identityId);
    else identity = await client.platform.identities.register();
    return identity;
  }
};
