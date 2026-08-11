<script>
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase';
  import { formatDate, formatCurrency } from '$lib/utils/helpers';

  let invoices = $state([]);
  let loading = $state(true);
  let search = $state('');
  let filterStatus = $state('all');

  let filteredInvoices = $derived(
    invoices.filter(inv => {
      const matchSearch = !search ||
        inv.patient_visitations?.patients?.full_name?.toLowerCase().includes(search.toLowerCase()) ||
        inv.patient_visitations?.patients?.no_rm?.toLowerCase().includes(search.toLowerCase());
      const matchStatus = filterStatus === 'all' ||
        (filterStatus === 'unpaid' && inv.status === 'unpaid') ||
        (filterStatus === 'paid' && inv.status === 'paid');
      return matchSearch && matchStatus;
    })
  );

  let stats = $derived({
    unpaid: invoices.filter(i => i.status === 'unpaid').length,
    paid: invoices.filter(i => i.status === 'paid').length,
    totalUnpaid: invoices.filter(i => i.status === 'unpaid').reduce((s, i) => s + (i.net_amount || 0), 0),
    totalPaid: invoices.filter(i => i.status === 'paid').reduce((s, i) => s + (i.net_amount || 0), 0)
  });

  async function loadInvoices() {
    loading = true;
    try {
      const { data, error } = await supabase
        .from('billing_invoices')
        .select(`
          *,
          patient_visitations (
            visit_id,
            patients (full_name, no_rm),
            clinics (name)
          )
        `)
        .order('created_at', { ascending: false });

      if (error) throw error;
      invoices = data || [];
    } catch (e) {
      console.error('Gagal memuat data:', e);
    } finally {
      loading = false;
    }
  }

  function goToDetail(visitId) {
    goto(`/kasir/${visitId}`);
  }

  $effect(() => {
    loadInvoices();
  });
</script>

<svelte:head>
  <title>Kasir / Billing - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Kasir / Billing</h1>
      <p class="text-sm text-gray-500 mt-1">Kelola tagihan dan pembayaran pasien</p>
    </div>
    <div class="flex items-center gap-2">
      <div class="px-3 py-1.5 bg-amber-50 border border-amber-200 rounded-lg">
        <span class="text-sm font-medium text-amber-700">{stats.unpaid} Belum Bayar ({formatCurrency(stats.totalUnpaid)})</span>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="flex flex-col sm:flex-row gap-4 mb-6">
      <div class="flex-1 relative">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input type="text" bind:value={search} placeholder="Cari nama atau no RM pasien..." class="input-field pl-10" />
      </div>
      <select bind:value={filterStatus} class="select-field sm:w-48">
        <option value="all">Semua Status</option>
        <option value="unpaid">Belum Bayar</option>
        <option value="paid">Sudah Bayar</option>
      </select>
    </div>

    {#if loading}
      <div class="flex items-center justify-center h-64">
        <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
      </div>
    {:else if filteredInvoices.length === 0}
      <div class="text-center py-12 text-gray-400">
        <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m3.75 9v6m3-3H9m1.5-12H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
        </svg>
        <p class="font-medium">Tidak ada tagihan ditemukan</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr>
              <th class="table-header px-4 py-3 text-left">Invoice</th>
              <th class="table-header px-4 py-3 text-left">No RM</th>
              <th class="table-header px-4 py-3 text-left">Pasien</th>
              <th class="table-header px-4 py-3 text-left">Poli</th>
              <th class="table-header px-4 py-3 text-left">Total</th>
              <th class="table-header px-4 py-3 text-left">Status</th>
              <th class="table-header px-4 py-3 text-left">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each filteredInvoices as inv}
              <tr class="hover:bg-gray-50">
                <td class="table-cell font-mono text-xs">{inv.invoice_id}</td>
                <td class="table-cell font-mono text-xs">{inv.patient_visitations?.patients?.no_rm || '-'}</td>
                <td class="table-cell font-medium">{inv.patient_visitations?.patients?.full_name || '-'}</td>
                <td class="table-cell">{inv.patient_visitations?.clinics?.name || '-'}</td>
                <td class="table-cell font-semibold">{formatCurrency(inv.net_amount)}</td>
                <td class="table-cell">
                  {#if inv.status === 'paid'}
                    <span class="badge badge-success">Lunas</span>
                  {:else if inv.status === 'partial'}
                    <span class="badge badge-info">Sebagian</span>
                  {:else}
                    <span class="badge badge-warning">Belum Bayar</span>
                  {/if}
                </td>
                <td class="table-cell">
                  <button
                    onclick={() => goToDetail(inv.visit_id)}
                    class="text-sm font-medium text-emerald-600 hover:text-emerald-700 transition-colors"
                  >
                    {inv.status === 'paid' ? 'Lihat' : 'Bayar'}
                  </button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>
