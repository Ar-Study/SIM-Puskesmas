<script>
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { createClient } from '$lib/supabaseClient';
  import { onMount } from 'svelte';

  const supabase = createClient();

  let countries = $state([]);
  let error = $state('');
  let isLoading = $state(true);

  onMount(async () => {
    const {
      data: { session }
    } = await supabase.auth.getSession();

    if (!session) {
      await goto(`${base}/login`);
      return;
    }

    const { data, error: queryError } = await supabase
      .from('countries')
      .select('name')
      .order('name');

    if (queryError) {
      error = queryError.message;
    } else {
      countries = data ?? [];
    }

    isLoading = false;
  });
</script>

<svelte:head>
  <title>SIM Puskesmas</title>
</svelte:head>

{#if isLoading}
  <p>Memuat data...</p>
{:else if error}
  <p>{error}</p>
{:else}
  <ul>
    {#each countries as country}
      <li>{country.name}</li>
    {/each}
  </ul>
{/if}
