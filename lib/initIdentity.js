export const initIdentity = async function (client, account) {
  let identity;
  let identityId = await account.identities.getIdentityIds()[0];
  console.log("identityId :>> ", identityId);
  if (identityId) identity = await client.platform.identities.get(identityId);
  else identity = await client.platform.identities.register();
  return identity;
};
