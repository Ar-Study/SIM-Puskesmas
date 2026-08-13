<script>
  import { onMount } from 'svelte';
  import { base } from '$app/paths';
  import { supabase } from '$lib/supabase';
  import { formatDate, formatCurrency } from '$lib/utils/helpers';

  let stats = $state({ patients: 0, visitsToday: 0, queueWaiting: 0, revenue: 0 });
  let recentVisits = $state([]);
  let loading = $state(true);

  function appPath(path) {
    return `${base}${path}`;
  }

  onMount(async () => {
    try {
      const today = new Date().toISOString().split('T')[0];

      const [patientsRes, visitsRes, queueRes, billsRes, recentRes] = await Promise.all([
        supabase.from('patients').select('patient_id', { count: 'exact', head: true }),
        supabase.from('patient_visitations').select('visit_id', { count: 'exact', head: true }).gte('visit_date', today),
        supabase.from('queue_numbers').select('id', { count: 'exact', head: true }).eq('queue_date', today).eq('status', 'waiting'),
        supabase.from('billing_invoices').select('net_amount').eq('status', 'paid').gte('created_at', today),
        supabase.from('patient_visitations').select('*, patients(full_name, no_rm), clinics(name)').order('created_at', { ascending: false }).limit(10)
      ]);

      stats.patients = patientsRes.count || 0;
      stats.visitsToday = visitsRes.count || 0;
      stats.queueWaiting = queueRes.count || 0;
      stats.revenue = billsRes.data?.reduce((sum, b) => sum + (b.net_amount || 0), 0) || 0;
      recentVisits = recentRes.data || [];
    } catch (e) {
      console.error('Dashboard error:', e);
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Dashboard - SMARTHEALTH</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center h-64">
    <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
  </div>
{:else}
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Dashboard</h1>
      <p class="text-sm text-gray-500 mt-1">Ringkasan aktivitas Puskesmas hari ini</p>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <div class="card">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
            <svg class="w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </div>
          <div>
            <p class="text-sm text-gray-500">Total Pasien</p>
            <p class="text-2xl font-bold text-gray-900">{stats.patients}</p>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-emerald-100 rounded-xl flex items-center justify-center">
            <svg class="w-6 h-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <div>
            <p class="text-sm text-gray-500">Kunjungan Hari Ini</p>
            <p class="text-2xl font-bold text-gray-900">{stats.visitsToday}</p>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-amber-100 rounded-xl flex items-center justify-center">
            <svg class="w-6 h-6 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div>
            <p class="text-sm text-gray-500">Antrian Menunggu</p>
            <p class="text-2xl font-bold text-gray-900">{stats.queueWaiting}</p>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
            <svg class="w-6 h-6 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z" />
            </svg>
          </div>
          <div>
            <p class="text-sm text-gray-500">Pendapatan Hari Ini</p>
            <p class="text-2xl font-bold text-gray-900">{formatCurrency(stats.revenue)}</p>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2 card">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Kunjungan Terakhir</h2>
        {#if recentVisits.length === 0}
          <div class="text-center py-8 text-gray-400">
            <p>Belum ada kunjungan hari ini</p>
          </div>
        {:else}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr>
                  <th class="table-header px-4 py-3 text-left">No RM</th>
                  <th class="table-header px-4 py-3 text-left">Nama Pasien</th>
                  <th class="table-header px-4 py-3 text-left">Poli</th>
                  <th class="table-header px-4 py-3 text-left">Status</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#each recentVisits as visit}
                  <tr class="hover:bg-gray-50">
                    <td class="table-cell">{visit.patients?.no_rm || '-'}</td>
                    <td class="table-cell font-medium">{visit.patients?.full_name || '-'}</td>
                    <td class="table-cell">{visit.clinics?.name || '-'}</td>
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

      <div class="card">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Akses Cepat</h2>
        <div class="space-y-3">
          <a href={appPath('/registrasi/tambah')} class="flex items-center gap-3 p-3 rounded-lg hover:bg-emerald-50 transition-colors">
            <div class="w-10 h-10 bg-emerald-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900">Registrasi Baru</p>
              <p class="text-xs text-gray-500">Daftarkan pasien baru</p>
            </div>
          </a>
          <a href={appPath('/apm')} class="flex items-center gap-3 p-3 rounded-lg hover:bg-blue-50 transition-colors">
            <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5h3m-6.75 2.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-15a2.25 2.25 0 0 0-2.25-2.25H6.75A2.25 2.25 0 0 0 4.5 4.5v15a2.25 2.25 0 0 0 2.25 2.25Z" />
              </svg>
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900">Antrian Mandiri</p>
              <p class="text-xs text-gray-500">Kiosk APM</p>
            </div>
          </a>
          <a href={appPath('/rawat-jalan')} class="flex items-center gap-3 p-3 rounded-lg hover:bg-purple-50 transition-colors">
            <div class="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6z" />
              </svg>
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900">Rawat Jalan</p>
              <p class="text-xs text-gray-500">Pemeriksaan pasien</p>
            </div>
          </a>
          <a href={appPath('/farmasi')} class="flex items-center gap-3 p-3 rounded-lg hover:bg-amber-50 transition-colors">
            <div class="w-10 h-10 bg-amber-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3" />
              </svg>
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900">Farmasi</p>
              <p class="text-xs text-gray-500">Stok & resep obat</p>
            </div>
          </a>
        </div>
      </div>
    </div>
  </div>
{/if}
