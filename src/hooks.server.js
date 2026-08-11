import { createServerClient } from '$lib/server/supabaseServer';

export async function handle({ event, resolve }) {
  event.locals.supabase = createServerClient({ cookies: event.cookies });

  event.locals.getSession = async () => {
    const {
      data: { session },
    } = await event.locals.supabase.auth.getSession();
    return session;
  };

  event.locals.getUser = async () => {
    const session = await event.locals.getSession();
    if (!session) return null;
    const { data: { user } } = await event.locals.supabase.auth.getUser();
    return user;
  };

  return resolve(event);
}
