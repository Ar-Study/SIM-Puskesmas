import { createBrowserClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY } from '$env/static/public';

export function createClient() {
  return createBrowserClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookies: {
        getAll: () => {
          const cookies = document.cookie
            .split(';')
            .map(c => c.trim())
            .filter(c => c)
            .map(c => {
              const [name, ...rest] = c.split('=');
              return { name: decodeURIComponent(name), value: decodeURIComponent(rest.join('=')) };
            });
          return cookies;
        },
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value, options }) => {
            let cookieStr = `${encodeURIComponent(name)}=${encodeURIComponent(value)}`;
            if (options.expires) cookieStr += `; expires=${options.expires.toUTCString()}`;
            if (options.maxAge) cookieStr += `; max-age=${options.maxAge}`;
            if (options.path) cookieStr += `; path=${options.path}`;
            if (options.domain) cookieStr += `; domain=${options.domain}`;
            if (options.secure) cookieStr += `; secure`;
            if (options.sameSite) cookieStr += `; samesite=${options.sameSite}`;
            if (options.httpOnly) cookieStr += `; httponly`;
            document.cookie = cookieStr;
          });
        },
      },
    }
  );
}
