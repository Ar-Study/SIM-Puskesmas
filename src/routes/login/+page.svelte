<script>
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { createClient } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  const supabase = createClient();

  let isLogin = $state(true);
  let isLoading = $state(false);
  let error = $state('');
  let success = $state('');
  let email = $state('');
  let password = $state('');
  let fullName = $state('');

  onMount(async () => {
    const {
      data: { session }
    } = await supabase.auth.getSession();

    if (session) {
      await goto(`${base}/`);
    }
  });

  function toggleMode() {
    error = '';
    success = '';
    isLogin = !isLogin;
  }

  async function submitForm() {
    isLoading = true;
    error = '';
    success = '';

    const response = isLogin
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: fullName
          }
        }
      });

    isLoading = false;

    if (response.error) {
      error = response.error.message;
      return;
    }

    if (isLogin) {
      await goto(`${base}/`);
      return;
    }

    success = 'Pendaftaran berhasil. Silakan cek email Anda untuk konfirmasi.';
    password = '';
    isLogin = true;
  }
</script>

<div class="auth-container">
  <div class="auth-card">
    <h1>{isLogin ? 'Login' : 'Daftar'}</h1>

    {#if error}
      <div class="error-message">{error}</div>
    {/if}

    {#if success}
      <div class="success-message">{success}</div>
    {/if}

    <form
      onsubmit={(event) => {
			event.preventDefault();
			submitForm();
		}}
    >
      {#if !isLogin}
        <div class="form-group">
          <label for="full_name">Nama Lengkap</label>
          <input
            type="text"
            id="full_name"
            name="full_name"
            placeholder="Masukkan nama lengkap"
            bind:value={fullName}
            required
          />
        </div>
      {/if}

      <div class="form-group">
        <label for="email">Email</label>
        <input
          type="email"
          id="email"
          name="email"
          placeholder="Masukkan email"
          bind:value={email}
          required
        />
      </div>

      <div class="form-group">
        <label for="password">Password</label>
        <input
          type="password"
          id="password"
          name="password"
          placeholder="Masukkan password"
          bind:value={password}
          required
          minlength="6"
        />
      </div>

      <button type="submit" class="auth-button" disabled={isLoading}>
        {isLoading ? 'Proses...' : (isLogin ? 'Login' : 'Daftar')}
      </button>
    </form>

    <p class="toggle-link">
      {isLogin ? 'Belum punya akun?' : 'Sudah punya akun?'}
      <button type="button" onclick={toggleMode} class="link-button">
        {isLogin ? 'Daftar' : 'Login'}
      </button>
    </p>
  </div>
</div>

<style>
  .auth-container {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    background: #f5f5f5;
  }

  .auth-card {
    background: white;
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
    width: 100%;
    max-width: 400px;
  }

  h1 {
    text-align: center;
    margin-bottom: 1.5rem;
    font-size: 1.5rem;
  }

  .form-group {
    margin-bottom: 1rem;
  }

  label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
  }

  input {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 0.9rem;
  }

  .auth-button {
    width: 100%;
    padding: 0.75rem;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 1rem;
    cursor: pointer;
    margin-top: 0.5rem;
  }

  .auth-button:hover:not(:disabled) {
    background: #2563eb;
  }

  .auth-button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .toggle-link {
    text-align: center;
    margin-top: 1rem;
    font-size: 0.9rem;
  }

  .link-button {
    background: none;
    border: none;
    color: #3b82f6;
    cursor: pointer;
    padding: 0;
    margin-left: 0.5rem;
  }

  .error-message {
    background: #fee2e2;
    color: #991b2b;
    padding: 0.75rem;
    border-radius: 4px;
    margin-bottom: 1rem;
    text-align: center;
  }

  .success-message {
    background: #dcfce7;
    color: #166534;
    padding: 0.75rem;
    border-radius: 4px;
    margin-bottom: 1rem;
    text-align: center;
  }
</style>
