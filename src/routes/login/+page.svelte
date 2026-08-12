<script>
  import { signIn } from '$lib/auth.js';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';

  let email = $state('');
  let password = $state('');
  let loading = $state(false);
  let error = $state('');
  let showPassword = $state(false);

  async function handleLogin(e) {
    e.preventDefault();
    error = '';
    loading = true;

    try {
      await signIn(email, password);
      goto(`${base}/`);
    } catch (err) {
      console.error('Login error:', err);
      if (err.message?.includes('Invalid login')) {
        error = 'Email atau password salah. Pastikan sudah membuat user di Supabase Auth.';
      } else if (err.message?.includes('fetch')) {
        error = 'Tidak bisa terhubung ke Supabase. Periksa URL dan Key di file .env';
      } else {
        error = err.message || 'Terjadi kesalahan saat login';
      }
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Login - SMARTHEALTH</title>
</svelte:head>

<div class="flex min-h-screen">
  <div class="hidden lg:flex lg:w-1/2 relative overflow-hidden bg-gradient-to-br from-emerald-600 via-emerald-700 to-emerald-900 items-center justify-center">
    <div class="absolute inset-0 overflow-hidden">
      <div class="absolute -top-32 -left-32 w-96 h-96 bg-white/5 rounded-full"></div>
      <div class="absolute -bottom-48 -left-24 w-[500px] h-[500px] bg-white/5 rounded-full"></div>
      <div class="absolute top-1/4 right-0 w-64 h-64 bg-white/5 rounded-full"></div>
      <div class="absolute top-20 left-20 w-16 h-16">
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-4 h-16 bg-white/10 rounded-full"></div>
        <div class="absolute top-1/2 left-0 -translate-y-1/2 w-16 h-4 bg-white/10 rounded-full"></div>
      </div>
      <div class="absolute bottom-32 right-24 w-20 h-20">
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-5 h-20 bg-white/10 rounded-full"></div>
        <div class="absolute top-1/2 left-0 -translate-y-1/2 w-20 h-5 bg-white/10 rounded-full"></div>
      </div>
    </div>

    <div class="relative z-10 text-center px-12 max-w-lg">
      <div class="w-28 h-28 mx-auto mb-8 bg-white/15 backdrop-blur-sm rounded-3xl flex items-center justify-center border border-white/20 shadow-2xl">
        <svg class="w-16 h-16 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342" />
        </svg>
      </div>

      <h1 class="text-5xl font-bold text-white mb-4 tracking-tight">SMARTHEALTH</h1>
      <p class="text-xl text-emerald-100 font-medium mb-3">Sistem Informasi Manajemen Puskesmas</p>
      <p class="text-lg text-emerald-200/80">Pelayanan Kesehatan Masyarakat Terpadu</p>

      <div class="mt-12 grid grid-cols-3 gap-6">
        <div class="bg-white/10 backdrop-blur-sm rounded-xl p-4 border border-white/10">
          <div class="w-10 h-10 mx-auto mb-2 bg-white/20 rounded-lg flex items-center justify-center">
            <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </div>
          <p class="text-xs text-emerald-100">Pasien</p>
        </div>
        <div class="bg-white/10 backdrop-blur-sm rounded-xl p-4 border border-white/10">
          <div class="w-10 h-10 mx-auto mb-2 bg-white/20 rounded-lg flex items-center justify-center">
            <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <p class="text-xs text-emerald-100">Rekam Medis</p>
        </div>
        <div class="bg-white/10 backdrop-blur-sm rounded-xl p-4 border border-white/10">
          <div class="w-10 h-10 mx-auto mb-2 bg-white/20 rounded-lg flex items-center justify-center">
            <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
          </div>
          <p class="text-xs text-emerald-100">Laporan</p>
        </div>
      </div>
    </div>
  </div>

  <div class="w-full lg:w-1/2 flex items-center justify-center p-8 bg-gray-50">
    <div class="w-full max-w-md">
      <div class="lg:hidden text-center mb-8">
        <div class="w-16 h-16 mx-auto mb-4 bg-emerald-600 rounded-2xl flex items-center justify-center shadow-lg">
          <svg class="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342" />
          </svg>
        </div>
        <h1 class="text-3xl font-bold text-gray-900">SMARTHEALTH</h1>
        <p class="text-sm text-gray-500 mt-1">Sistem Informasi Manajemen Puskesmas</p>
      </div>

      <div class="bg-white rounded-2xl shadow-xl border border-gray-100 p-8">
        <div class="text-center mb-8">
          <h2 class="text-2xl font-bold text-gray-900">Selamat Datang</h2>
          <p class="text-gray-500 mt-2">Masuk ke akun Anda untuk melanjutkan</p>
        </div>

        {#if error}
          <div class="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl flex items-start gap-3">
            <svg class="w-5 h-5 text-red-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p class="text-sm text-red-600">{error}</p>
          </div>
        {/if}

        <form onsubmit={handleLogin} class="space-y-5">
          <div>
            <label for="email" class="block text-sm font-medium text-gray-700 mb-1.5">Email</label>
            <input
              id="email"
              type="email"
              bind:value={email}
              placeholder="Masukkan email"
              required
              disabled={loading}
              class="w-full px-4 py-3 rounded-xl border border-gray-300 bg-white text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-all duration-200 disabled:bg-gray-100 disabled:cursor-not-allowed"
            />
          </div>

          <div>
            <label for="password" class="block text-sm font-medium text-gray-700 mb-1.5">Password</label>
            <div class="relative">
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                bind:value={password}
                placeholder="Masukkan password"
                required
                disabled={loading}
                class="w-full px-4 py-3 pr-12 rounded-xl border border-gray-300 bg-white text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 transition-all duration-200 disabled:bg-gray-100 disabled:cursor-not-allowed"
              />
              <button
                type="button"
                onclick={() => showPassword = !showPassword}
                class="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-gray-400 hover:text-gray-600 transition-colors"
              >
                {#if showPassword}
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                  </svg>
                {:else}
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                {/if}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading || !email || !password}
            class="w-full py-3 px-4 bg-emerald-600 text-white font-semibold rounded-xl hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2 transition-all duration-200 disabled:bg-emerald-400 disabled:cursor-not-allowed shadow-lg shadow-emerald-600/25 flex items-center justify-center gap-2"
          >
            {#if loading}
              <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span>Memproses...</span>
            {:else}
              <span>Masuk</span>
            {/if}
          </button>
        </form>

        <div class="mt-4 p-4 bg-amber-50 border border-amber-200 rounded-xl">
          <p class="text-xs text-amber-700 font-semibold mb-2">Pertama kali setup?</p>
          <ol class="text-xs text-amber-600 space-y-1 list-decimal list-inside">
            <li>Buka Supabase Dashboard</li>
            <li>Jalankan SQL di <code class="bg-amber-100 px-1 rounded">supabase/migrations/001_initial_schema.sql</code></li>
            <li>Jalankan seed di <code class="bg-amber-100 px-1 rounded">002_seed_data.sql</code></li>
            <li>Jalankan RLS di <code class="bg-amber-100 px-1 rounded">003_rls_policies.sql</code></li>
            <li>Buat user di Auth > Users (email & password)</li>
            <li>Isi URL dan Key di <code class="bg-amber-100 px-1 rounded">.env</code></li>
          </ol>
        </div>

        <div class="mt-4 p-4 bg-emerald-50 border border-emerald-100 rounded-xl">
          <p class="text-xs text-emerald-600 text-center">
            <span class="font-medium">Demo:</span> admin@smarthealth.com / password123
          </p>
          <p class="text-[10px] text-emerald-400 text-center mt-1">
            (Buat user di Supabase Auth > Users terlebih dahulu)
          </p>
        </div>
      </div>

      <p class="text-center text-sm text-gray-400 mt-6">
        &copy; 2026 SMARTHEALTH. Hak cipta dilindungi.
      </p>
    </div>
  </div>
</div>
