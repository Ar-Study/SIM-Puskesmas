import { createServerClient as createServerSupabaseClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY } from '$env/static/public';

/** @param {{ cookies: import('@sveltejs/kit').Cookies }} param0 */
export function createServerClient({ cookies }) {
  return createServerSupabaseClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookies: {
        getAll: () => {
          return cookies.getAll().map(({ name, value }) => ({ name, value }));
        },
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookies.set(name, value, { ...options, path: '/' });
          });
        },
      },
      cookieOptions: {
        httpOnly: true,
        sameSite: 'lax',
        secure: true,
        maxAge: 60 * 60 * 24 * 30,
      },
      auth: {
        flowType: 'pkce',
      },
    }
  );
}
