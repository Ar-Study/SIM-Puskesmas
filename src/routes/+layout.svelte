<script>
  let { data, children } = $props();
</script>

{#if data?.user}
  <nav>
    <span>Selamat datang, {data.user.email}</span>
    <a href="/logout">Logout</a>
  </nav>
{:else}
  <nav>
    <a href="/login">Login</a>
  </nav>
{/if}

{@render children()}
