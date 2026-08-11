<script>
  import { supabase } from '$lib/supabase';
  import { formatDate, formatDateTime } from '$lib/utils/helpers';

  let tokens = $state([]);
  let syncData = $state([]);
  let loading = $state(true);

  async function loadData() {
    loading = true;
    try {
      const [tokenRes, syncRes] = await Promise.all([
        supabase.from('satusehat_tokens').select('*').order('created_at', { ascending: false }).limit(5),
        supabase
          .from('integrasi_satusehat')
          .select(`
            *,
            patient_visitations (
              visit_id,
              visit_date,
              patients (full_name, no_rm),
              clinics (name)
            )
          `)
          .order('created_at', { ascending: false })
          .limit(20)
      ]);

      tokens = tokenRes.data || [];
      syncData = syncRes.data || [];
    } catch (e) {
      console.error('Gagal memuat data:', e);
    } finally {
      loading = false;
    }
  }

  function getTokenStatus(token) {
    if (!token) return 'none';
    const expires = new Date(token.expires_at);
    if (expires < new Date()) return 'expired';
    return 'active';
  }

  $effect(() => {
    loadData();
  });
</script>

<svelte:head>
  <title>Bridging SatuSehat - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Bridging SatuSehat</h1>
    <p class="text-sm text-gray-500 mt-1">Integrasi dengan SatuSehat (FHIR Indonesia)</p>
  </div>

  <div class="card bg-blue-50 border-blue-200">
    <div class="flex items-start gap-3">
      <svg class="w-5 h-5 text-blue-600 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
      </svg>
      <div>
        <p class="text-sm font-semibold text-blue-800">Integrasi SatuSehat (Mock)</p>
        <p class="text-sm text-blue-700">Integrasi FHIR API SatuSehat yang sebenarnya akan ditambahkan di versi berikutnya. Saat ini menampilkan status sinkronisasi simulasi.</p>
      </div>
    </div>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <div class="card">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Token Management</h3>
      {#if loading}
        <div class="flex items-center justify-center h-32">
          <div class="w-6 h-6 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
        </div>
      {:else if tokens.length === 0}
        <div class="text-center py-8 text-gray-400">
          <svg class="w-10 h-10 mx-auto mb-2 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1121.75 8.25z" />
          </svg>
          <p class="text-sm font-medium">Belum ada token</p>
          <p class="text-xs mt-1">Token akan dibuat saat integrasi aktif</p>
        </div>
      {:else}
        <div class="space-y-3">
          {#each tokens as token}
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <p class="text-sm font-medium text-gray-700">Token #{token.id}</p>
                <p class="text-xs text-gray-500">Org: {token.org_id || '-'} | Expired: {formatDateTime(token.expires_at)}</p>
              </div>
              <span class="badge {getTokenStatus(token) === 'active' ? 'badge-success' : 'badge-danger'}">
                {getTokenStatus(token) === 'active' ? 'Aktif' : 'Expired'}
              </span>
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <div class="card">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Info Integrasi</h3>
      <div class="space-y-3">
        <div class="p-3 bg-gray-50 rounded-lg">
          <p class="text-xs text-gray-500">Status Koneksi</p>
          <p class="text-sm font-semibold"><span class="badge badge-warning">Mock Mode</span></p>
        </div>
        <div class="p-3 bg-gray-50 rounded-lg">
          <p class="text-xs text-gray-500">FHIR Version</p>
          <p class="text-sm font-semibold">R4 (4.0.1)</p>
        </div>
        <div class="p-3 bg-gray-50 rounded-lg">
          <p class="text-xs text-gray-500">Base URL</p>
          <p class="text-sm font-semibold font-mono text-xs">https://api-satusehat-stg.dto.kemkes.go.id</p>
        </div>
        <div class="p-3 bg-gray-50 rounded-lg">
          <p class="text-xs text-gray-500">Resources Tersinkron</p>
          <p class="text-sm font-semibold">{syncData.length} kunjungan</p>
        </div>
      </div>
    </div>
  </div>

  <div class="card">
    <h3 class="text-lg font-semibold text-gray-900 mb-4">Status Sinkronisasi per Kunjungan</h3>
    {#if loading}
      <div class="flex items-center justify-center h-32">
        <div class="w-6 h-6 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
      </div>
    {:else if syncData.length === 0}
      <div class="text-center py-12 text-gray-400">
        <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z" />
        </svg>
        <p class="font-medium">Belum ada data sinkronisasi</p>
        <p class="text-sm mt-1">Data akan muncul setelah integrasi aktif</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr>
              <th class="table-header px-4 py-3 text-left">Tanggal</th>
              <th class="table-header px-4 py-3 text-left">No RM</th>
              <th class="table-header px-4 py-3 text-left">Pasien</th>
              <th class="table-header px-4 py-3 text-left">Poli</th>
              <th class="table-header px-4 py-3 text-left">Encounter</th>
              <th class="table-header px-4 py-3 text-left">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each syncData as s}
              <tr class="hover:bg-gray-50">
                <td class="table-cell">{formatDate(s.patient_visitations?.visit_date)}</td>
                <td class="table-cell font-mono text-xs">{s.patient_visitations?.patients?.no_rm || '-'}</td>
                <td class="table-cell font-medium">{s.patient_visitations?.patients?.full_name || '-'}</td>
                <td class="table-cell">{s.patient_visitations?.clinics?.name || '-'}</td>
                <td class="table-cell font-mono text-xs">{s.encounter_fhir_id ? 'Tersinkron' : 'Belum'}</td>
                <td class="table-cell">
                  {#if s.encounter_fhir_id}
                    <span class="badge badge-success">Tersinkron</span>
                  {:else}
                    <span class="badge badge-gray">Belum</span>
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
