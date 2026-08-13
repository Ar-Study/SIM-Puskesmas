<script>
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { supabase } from '$lib/supabase';
  import { formatDate, calculateAge } from '$lib/utils/helpers';

  let patients = $state([]);
  let loading = $state(true);
  let search = $state('');
  let searchTimeout = $state(null);

  function appPath(path) {
    return `${base}${path}`;
  }

  async function searchPatients() {
    loading = true;
    try {
      let query = supabase
        .from('patients')
        .select(`
          *,
          patient_visitations!inner (
            visit_id,
            visit_date,
            clinics (name)
          )
        `)
        .order('created_at', { ascending: false })
        .limit(50);

      if (search) {
        query = query.or(`full_name.ilike.%${search}%,no_rm.ilike.%${search}%,nik.ilike.%${search}%`);
      }

      const { data, error } = await query;
      if (error) throw error;

      const patientsWithLastVisit = (data || []).map(p => {
        const visits = p.patient_visitations || [];
        const sorted = [...visits].sort((a, b) => new Date(b.visit_date) - new Date(a.visit_date));
        return { ...p, lastVisit: sorted[0] || null };
      });

      patients = patientsWithLastVisit;
    } catch (e) {
      console.error('Gagal mencari pasien:', e);
    } finally {
      loading = false;
    }
  }

  function handleSearch(e) {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => searchPatients(), 300);
  }

  function goToDetail(patientId) {
    goto(appPath(`/rekam-medis/${patientId}`));
  }

  $effect(() => {
    searchPatients();
  });
</script>

<svelte:head>
  <title>Rekam Medis - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Rekam Medis</h1>
    <p class="text-sm text-gray-500 mt-1">Cari dan lihat riwayat rekam medis pasien</p>
  </div>

  <div class="card">
    <div class="mb-6">
      <div class="relative">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          type="text"
          bind:value={search}
          oninput={handleSearch}
          placeholder="Cari berdasarkan nama, No RM, atau NIK..."
          class="input-field pl-10"
        />
      </div>
    </div>

    {#if loading}
      <div class="flex items-center justify-center h-64">
        <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
      </div>
    {:else if patients.length === 0}
      <div class="text-center py-12 text-gray-400">
        <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
        </svg>
        <p class="font-medium">Tidak ada data ditemukan</p>
        <p class="text-sm mt-1">Coba kata kunci pencarian lain</p>
      </div>
    {:else}
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {#each patients as patient}
          <button
            onclick={() => goToDetail(patient.patient_id)}
            class="text-left p-4 border border-gray-200 rounded-xl hover:border-emerald-300 hover:bg-emerald-50 transition-all duration-200 group"
          >
            <div class="flex items-start gap-3">
              <div class="w-10 h-10 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center text-sm font-bold flex-shrink-0 group-hover:bg-emerald-200 transition-colors">
                {patient.full_name?.charAt(0) || '?'}
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-semibold text-gray-900 truncate">{patient.full_name}</p>
                <p class="text-xs text-gray-500 mt-0.5">
                  RM: {patient.no_rm} | {patient.gender === 'L' ? 'Laki-laki' : 'Perempuan'} | {calculateAge(patient.date_of_birth)}
                </p>
                <div class="mt-2 flex items-center gap-2">
                  {#if patient.lastVisit}
                    <span class="text-xs text-gray-500">
                      Kunjungan terakhir: {formatDate(patient.lastVisit.visit_date)}
                    </span>
                    <span class="text-xs text-gray-300">|</span>
                    <span class="text-xs text-gray-500">{patient.lastVisit.clinics?.name || '-'}</span>
                  {:else}
                    <span class="text-xs text-gray-400">Belum ada kunjungan</span>
                  {/if}
                </div>
              </div>
              <svg class="w-5 h-5 text-gray-300 group-hover:text-emerald-500 transition-colors flex-shrink-0 mt-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
              </svg>
            </div>
          </button>
        {/each}
      </div>
    {/if}
  </div>
</div>
