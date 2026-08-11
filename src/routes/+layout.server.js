export async function load({ locals }) {
  const session = await locals.getSession();
  const user = await locals.getUser();
  return {
    session,
    user,
  };
}
