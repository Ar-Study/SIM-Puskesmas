import { redirect } from '@sveltejs/kit';

export async function load({ locals }) {
  const session = await locals.getSession();
  if (session) {
    throw redirect(302, '/');
  }
}

export const actions = {
  login: async ({ request, locals }) => {
    const formData = await request.formData();
    const email = /** @type {string} */ (formData.get('email'));
    const password = /** @type {string} */ (formData.get('password'));

    const { error } = await locals.supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      return { error: error.message, email };
    }

    throw redirect(302, '/');
  },

  register: async ({ request, locals }) => {
    const formData = await request.formData();
    const email = /** @type {string} */ (formData.get('email'));
    const password = /** @type {string} */ (formData.get('password'));
    const full_name = /** @type {string} */ (formData.get('full_name'));

    const { error } = await locals.supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name,
        },
      },
    });

    if (error) {
      return { error: error.message, email };
    }

    return { success: 'Pendaftaran berhasil. Silakan cek email Anda untuk konfirmasi.' };
  },
};
