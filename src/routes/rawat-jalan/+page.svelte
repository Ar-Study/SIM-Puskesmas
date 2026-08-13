<script>
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { supabase } from '$lib/supabase';
  import { formatDate } from '$lib/utils/helpers';
  import { STATUS_PERIKSA } from '$lib/utils/constants';

  let visits = $state([]);
  let loading = $state(true);
  let search = $state('');
  let filterStatus = $state('all');

  function appPath(path) {
    return `${base}${path}`;
  }

  let filteredVisits = $derived(
    visits.filter(v => {
      const matchSearch = !search ||
        v.patients?.full_name?.toLowerCase().includes(search.toLowerCase()) ||
        v.patients?.no_rm?.toLowerCase().includes(search.toLowerCase());
      const matchStatus = filterStatus === 'all' ||
        (filterStatus === 'waiting' && v.status_periksa === '0') ||
        (filterStatus === 'done' && v.status_periksa === '1');
      return matchSearch && matchStatus;
    })
  );

  let stats = $derived({
    waiting: visits.filter(v => v.status_periksa === '0').length,
    done: visits.filter(v => v.status_periksa === '1').length,
    total: visits.length
  });

  async function loadVisits() {
    loading = true;
    try {
      const today = new Date().toISOString().split('T')[0];
      const { data, error } = await supabase
        .from('patient_visitations')
        .select(`
          *,
          patients (patient_id, full_name, no_rm, gender, phone),
          clinics (clinic_id, name),
          employees (employee_id, full_name)
        `)
        .gte('visit_date', today)
        .in('visit_type', ['rawat_jalan', 'igd'])
        .order('created_at', { ascending: true });
      if (error) throw error;
      visits = data || [];
    } catch (e) {
      console.error('Gagal memuat data:', e);
    } finally {
      loading = false;
    }
  }

  function goToDetail(visitId) {
    goto(appPath(`/rawat-jalan/${visitId}`));
  }

  $effect(() => {
    loadVisits();
  });
</script>

<svelte:head>
  <title>Rawat Jalan - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Rawat Jalan</h1>
      <p class="text-sm text-gray-500 mt-1">Daftar kunjungan pasien hari ini</p>
    </div>
    <div class="flex items-center gap-2">
      <div class="flex items-center gap-2 px-3 py-1.5 bg-amber-50 border border-amber-200 rounded-lg">
        <div class="w-2 h-2 bg-amber-500 rounded-full animate-pulse"></div>
        <span class="text-sm font-medium text-amber-700">{stats.waiting} Menunggu</span>
      </div>
      <div class="flex items-center gap-2 px-3 py-1.5 bg-emerald-50 border border-emerald-200 rounded-lg">
        <div class="w-2 h-2 bg-emerald-500 rounded-full"></div>
        <span class="text-sm font-medium text-emerald-700">{stats.done} Selesai</span>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="flex flex-col sm:flex-row gap-4 mb-6">
      <div class="flex-1 relative">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          type="text"
          bind:value={search}
          placeholder="Cari nama atau no RM..."
          class="input-field pl-10"
        />
      </div>
      <select bind:value={filterStatus} class="select-field sm:w-48">
        <option value="all">Semua Status</option>
        <option value="waiting">Menunggu</option>
        <option value="done">Selesai</option>
      </select>
    </div>

    {#if loading}
      <div class="flex items-center justify-center h-64">
        <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
      </div>
    {:else if filteredVisits.length === 0}
      <div class="text-center py-12 text-gray-400">
        <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
        </svg>
        <p class="font-medium">Tidak ada data ditemukan</p>
        <p class="text-sm mt-1">Belum ada kunjungan hari ini atau sesuai pencarian</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr>
              <th class="table-header px-4 py-3 text-left">No RM</th>
              <th class="table-header px-4 py-3 text-left">Nama Pasien</th>
              <th class="table-header px-4 py-3 text-left">Poli</th>
              <th class="table-header px-4 py-3 text-left">Dokter</th>
              <th class="table-header px-4 py-3 text-left">Jam Datang</th>
              <th class="table-header px-4 py-3 text-left">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each filteredVisits as visit}
              <tr
                class="hover:bg-gray-50 cursor-pointer transition-colors"
                onclick={() => goToDetail(visit.visit_id)}
              >
                <td class="table-cell font-mono text-xs">{visit.patients?.no_rm || '-'}</td>
                <td class="table-cell font-medium">{visit.patients?.full_name || '-'}</td>
                <td class="table-cell">
                  <span class="inline-flex items-center gap-1.5">
                    <span class="w-2 h-2 bg-purple-500 rounded-full"></span>
                    {visit.clinics?.name || '-'}
                  </span>
                </td>
                <td class="table-cell">{visit.employees?.full_name || '-'}</td>
                <td class="table-cell text-gray-500">{formatDate(visit.visit_date)}</td>
                <td class="table-cell">
                  {#if visit.status_periksa === '1'}
                    <span class="badge badge-success">Selesai</span>
                  {:else}
                    <span class="badge badge-warning">Menunggu</span>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>
