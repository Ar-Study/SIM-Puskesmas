<script>
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { supabase } from '$lib/supabase';
  import { formatDate, formatCurrency } from '$lib/utils/helpers';

  let prescriptions = $state([]);
  let drugs = $state([]);
  let loading = $state(true);
  let activeTab = $state('prescriptions');
  let searchDrug = $state('');
  let searchPrescription = $state('');

  function appPath(path) {
    return `${base}${path}`;
  }

  let filteredPrescriptions = $derived(
    prescriptions.filter(p => {
      const matchSearch = !searchPrescription ||
        p.patient_visitations?.patients?.full_name?.toLowerCase().includes(searchPrescription.toLowerCase()) ||
        p.patient_visitations?.patients?.no_rm?.toLowerCase().includes(searchPrescription.toLowerCase());
      return matchSearch;
    })
  );

  let filteredDrugs = $derived(
    drugs.filter(d => {
      const matchSearch = !searchDrug ||
        d.name?.toLowerCase().includes(searchDrug.toLowerCase()) ||
        d.generic_name?.toLowerCase().includes(searchDrug.toLowerCase());
      return matchSearch;
    })
  );

  async function loadData() {
    loading = true;
    try {
      const [prescRes, drugsRes] = await Promise.all([
        supabase
          .from('prescriptions')
          .select(`
            *,
            patient_visitations (
              visit_id,
              patients (full_name, no_rm),
              clinics (name)
            ),
            employees (full_name),
            prescription_items (
              *,
              drugs (name, generic_name, unit, stock)
            )
          `)
          .order('created_at', { ascending: false }),
        supabase.from('drugs').select('*').eq('is_active', true).order('name')
      ]);

      if (prescRes.error) throw prescRes.error;
      if (drugsRes.error) throw drugsRes.error;

      prescriptions = prescRes.data || [];
      drugs = drugsRes.data || [];
    } catch (e) {
      console.error('Gagal memuat data:', e);
    } finally {
      loading = false;
    }
  }

  function goToPrescription(id) {
    goto(appPath(`/farmasi/resep/${id}`));
  }

  $effect(() => {
    loadData();
  });
</script>

<svelte:head>
  <title>Farmasi - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Farmasi</h1>
    <p class="text-sm text-gray-500 mt-1">Kelola resep obat dan stok farmasi</p>
  </div>

  <div class="card">
    <div class="flex gap-2 mb-6 border-b border-gray-200 pb-2">
      <button
        onclick={() => activeTab = 'prescriptions'}
        class="px-4 py-2 rounded-lg font-medium text-sm transition-colors {activeTab === 'prescriptions' ? 'bg-emerald-600 text-white' : 'text-gray-600 hover:bg-gray-100'}"
      >
        Resep Masuk
      </button>
      <button
        onclick={() => activeTab = 'stock'}
        class="px-4 py-2 rounded-lg font-medium text-sm transition-colors {activeTab === 'stock' ? 'bg-emerald-600 text-white' : 'text-gray-600 hover:bg-gray-100'}"
      >
        Stok Obat
      </button>
    </div>

    {#if loading}
      <div class="flex items-center justify-center h-64">
        <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
      </div>
    {:else if activeTab === 'prescriptions'}
      <div>
        <div class="mb-4 relative">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <input type="text" bind:value={searchPrescription} placeholder="Cari nama atau no RM pasien..." class="input-field pl-10" />
        </div>
        {#if filteredPrescriptions.length === 0}
          <div class="text-center py-12 text-gray-400">
            <p class="font-medium">Tidak ada resep ditemukan</p>
          </div>
        {:else}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr>
                  <th class="table-header px-4 py-3 text-left">No RM</th>
                  <th class="table-header px-4 py-3 text-left">Pasien</th>
                  <th class="table-header px-4 py-3 text-left">Dokter</th>
                  <th class="table-header px-4 py-3 text-left">Poli</th>
                  <th class="table-header px-4 py-3 text-left">Item</th>
                  <th class="table-header px-4 py-3 text-left">Status</th>
                  <th class="table-header px-4 py-3 text-left">Aksi</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredPrescriptions as presc}
                  <tr class="hover:bg-gray-50">
                    <td class="table-cell font-mono text-xs">{presc.patient_visitations?.patients?.no_rm || '-'}</td>
                    <td class="table-cell font-medium">{presc.patient_visitations?.patients?.full_name || '-'}</td>
                    <td class="table-cell">{presc.employees?.full_name || '-'}</td>
                    <td class="table-cell">{presc.patient_visitations?.clinics?.name || '-'}</td>
                    <td class="table-cell">{presc.prescription_items?.length || 0} obat</td>
                    <td class="table-cell">
                      {#if presc.status === 'dispensed'}
                        <span class="badge badge-success">Sudah Diambil</span>
                      {:else if presc.status === 'cancelled'}
                        <span class="badge badge-danger">Dibatalkan</span>
                      {:else}
                        <span class="badge badge-warning">Menunggu</span>
                      {/if}
                    </td>
                    <td class="table-cell">
                      <button
                        onclick={() => goToPrescription(presc.id)}
                        class="text-sm font-medium text-emerald-600 hover:text-emerald-700 transition-colors"
                      >
                        Lihat Detail
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    {:else}
      <div>
        <div class="mb-4 relative">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <input type="text" bind:value={searchDrug} placeholder="Cari nama obat..." class="input-field pl-10" />
        </div>
        {#if filteredDrugs.length === 0}
          <div class="text-center py-12 text-gray-400">
            <p class="font-medium">Tidak ada obat ditemukan</p>
          </div>
        {:else}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr>
                  <th class="table-header px-4 py-3 text-left">Nama Obat</th>
                  <th class="table-header px-4 py-3 text-left">Generik</th>
                  <th class="table-header px-4 py-3 text-left">Kategori</th>
                  <th class="table-header px-4 py-3 text-left">Stok</th>
                  <th class="table-header px-4 py-3 text-left">Min. Stok</th>
                  <th class="table-header px-4 py-3 text-left">Harga Jual</th>
                  <th class="table-header px-4 py-3 text-left">Status</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each filteredDrugs as drug}
                  <tr class="hover:bg-gray-50">
                    <td class="table-cell font-medium">{drug.name}</td>
                    <td class="table-cell text-gray-500">{drug.generic_name || '-'}</td>
                    <td class="table-cell">{drug.category || '-'}</td>
                    <td class="table-cell">{drug.stock} {drug.unit}</td>
                    <td class="table-cell">{drug.min_stock}</td>
                    <td class="table-cell">{formatCurrency(drug.sell_price)}</td>
                    <td class="table-cell">
                      {#if drug.stock <= 0}
                        <span class="badge badge-danger">Habis</span>
                      {:else if drug.stock <= drug.min_stock}
                        <span class="badge badge-warning">Menipis</span>
                      {:else}
                        <span class="badge badge-success">Tersedia</span>
                      {/if}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>
