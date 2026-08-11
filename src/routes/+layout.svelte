<script>
  import { base } from '$app/paths';
  import { createClient } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  const supabase = createClient();

  let { children } = $props();
  let user = $state(null);

  onMount(() => {
    let active = true;

    const loadSession = async () => {
      const {
        data: { session }
      } = await supabase.auth.getSession();

      if (active) {
        user = session?.user ?? null;
      }
    };

    loadSession();

    const {
      data: { subscription }
    } = supabase.auth.onAuthStateChange((_event, session) => {
      user = session?.user ?? null;
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  });

  async function logout() {
    await supabase.auth.signOut();
    window.location.href = `${base}/login`;
  }
</script>

<nav>
  <a href={`${base}/`}>SIM Puskesmas</a>

  <div>
    {#if user}
      <span>Selamat datang, {user.email}</span>
      <button type="button" onclick={logout}>Logout</button>
    {:else}
      <a href={`${base}/login`}>Login</a>
    {/if}
  </div>
</nav>

{@render children()}

<style>
  nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    background: #ffffff;
  }

  nav > a {
    color: #111827;
    font-weight: 700;
    text-decoration: none;
  }

  nav div {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  span {
    color: #374151;
    font-size: 0.95rem;
  }

  button,
  nav div a {
    border: 0;
    background: #2563eb;
    color: #ffffff;
    padding: 0.5rem 0.9rem;
    border-radius: 0.5rem;
    font: inherit;
    text-decoration: none;
    cursor: pointer;
  }
</style>
