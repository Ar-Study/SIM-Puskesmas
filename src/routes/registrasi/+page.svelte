<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase';
  import { formatDate } from '$lib/utils/helpers';
  import { STATUS_PEMBAYARAN, STATUS_PERIKSA } from '$lib/utils/constants';

  let visits = $state([]);
  let loading = $state(true);
  let searchQuery = $state('');
  let filterDate = $state(new Date().toISOString().split('T')[0]);
  let debounceTimer;

  async function fetchVisits() {
    loading = true;
    try {
      let query = supabase
        .from('patient_visitations')
        .select('*, patients(full_name, no_rm, nik), clinics(name), employees(full_name:doctor_name)')
        .order('created_at', { ascending: false });

      if (filterDate) {
        query = query.gte('visit_date', filterDate + 'T00:00:00').lte('visit_date', filterDate + 'T23:59:59');
      }

      if (searchQuery.trim()) {
        const q = searchQuery.trim().toLowerCase();
        query = query.or(`patients.full_name.ilike.%${q}%,patients.no_rm.ilike.%${q}%,patients.nik.ilike.%${q}%`);
      }

      const { data, error } = await query;
      if (error) throw error;
      visits = data || [];
    } catch (e) {
      console.error('Gagal memuat data registrasi:', e);
      visits = [];
    } finally {
      loading = false;
    }
  }

  function handleSearch(e) {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      fetchVisits();
    }, 300);
  }

  function handleDateChange() {
    fetchVisits();
  }

  function resetDate() {
    filterDate = new Date().toISOString().split('T')[0];
    fetchVisits();
  }

  onMount(() => {
    fetchVisits();
  });
</script>

<svelte:head>
  <title>Registrasi Pasien - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Registrasi Pasien</h1>
      <p class="text-sm text-gray-500 mt-1">Daftar kunjungan pasien hari ini</p>
    </div>
    <a
      href="/registrasi/tambah"
      class="btn-success flex items-center gap-2 w-fit"
    >
      <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
      </svg>
      Registrasi Baru
    </a>
  </div>

  <div class="card">
    <div class="flex flex-col sm:flex-row gap-4">
      <div class="flex-1">
        <label for="search" class="label">Cari Pasien</label>
        <div class="relative">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
          </svg>
          <input
            id="search"
            type="text"
            bind:value={searchQuery}
            oninput={handleSearch}
            placeholder="Cari nama, No RM, atau NIK..."
            class="input-field pl-10"
          />
        </div>
      </div>
      <div class="sm:w-48">
        <label for="filter-date" class="label">Tanggal</label>
        <input
          id="filter-date"
          type="date"
          bind:value={filterDate}
          onchange={handleDateChange}
          class="input-field"
        />
      </div>
      <div class="flex items-end">
        <button
          class="btn-secondary flex items-center gap-2"
          onclick={resetDate}
        >
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182" />
          </svg>
          Hari Ini
        </button>
      </div>
    </div>
  </div>

  {#if loading}
    <div class="flex items-center justify-center h-64">
      <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
    </div>
  {:else if visits.length === 0}
    <div class="card">
      <div class="text-center py-12">
        <svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
        </svg>
        <p class="text-gray-500 font-medium">Tidak ada data registrasi</p>
        <p class="text-sm text-gray-400 mt-1">Belum ada kunjungan pada tanggal ini</p>
        <a href="/registrasi/tambah" class="btn-success mt-4 inline-flex items-center gap-2">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          Registrasi Sekarang
        </a>
      </div>
    </div>
  {:else}
    <div class="card p-0 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr>
              <th class="table-header px-4 py-3 text-left">No RM</th>
              <th class="table-header px-4 py-3 text-left">Nama Pasien</th>
              <th class="table-header px-4 py-3 text-left">Poli</th>
              <th class="table-header px-4 py-3 text-left">Dokter</th>
              <th class="table-header px-4 py-3 text-left">Tanggal</th>
              <th class="table-header px-4 py-3 text-left">Status Bayar</th>
              <th class="table-header px-4 py-3 text-left">Status Periksa</th>
              <th class="table-header px-4 py-3 text-center">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each visits as visit}
              <tr class="hover:bg-gray-50 transition-colors">
                <td class="table-cell font-mono text-xs">{visit.patients?.no_rm || '-'}</td>
                <td class="table-cell font-medium">{visit.patients?.full_name || '-'}</td>
                <td class="table-cell">
                  <span class="badge badge-info">{visit.clinics?.name || '-'}</span>
                </td>
                <td class="table-cell">{visit.doctor_name || '-'}</td>
                <td class="table-cell text-xs">{formatDate(visit.visit_date)}</td>
                <td class="table-cell">
                  {#if visit.status_pembayaran === '1'}
                    <span class="badge badge-success">Sudah Bayar</span>
                  {:else if visit.status_pembayaran === '2'}
                    <span class="badge badge-info">Gratis</span>
                  {:else}
                    <span class="badge badge-warning">Belum Bayar</span>
                  {/if}
                </td>
                <td class="table-cell">
                  {#if visit.status_periksa === '1'}
                    <span class="badge badge-success">Selesai</span>
                  {:else}
                    <span class="badge badge-warning">Menunggu</span>
                  {/if}
                </td>
                <td class="table-cell text-center">
                  <a
                    href="/registrasi/{visit.visit_id}"
                    class="inline-flex items-center gap-1 text-sm text-primary-600 hover:text-primary-800 font-medium transition-colors"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                    </svg>
                    Detail
                  </a>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  {/if}
</div>
