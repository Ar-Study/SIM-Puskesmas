<script>
  import { supabase } from '$lib/supabase';
  import { formatDate } from '$lib/utils/helpers';

  let orders = $state([]);
  let catalog = $state([]);
  let loading = $state(true);
  let search = $state('');
  let activeTab = $state('incoming');
  let selectedOrder = $state(null);
  let analysisResults = $state({});
  let saving = $state(false);

  let filteredOrders = $derived(
    orders.filter(o => {
      const matchSearch = !search || o.patient_visitations?.patients?.full_name?.toLowerCase().includes(search.toLowerCase());
      const matchTab = (activeTab === 'incoming' && (o.status === 'ordered' || o.status === 'in_progress')) ||
        (activeTab === 'completed' && o.status === 'completed');
      return matchSearch && matchTab;
    })
  );

  async function loadOrders() {
    loading = true;
    try {
      const [ordersRes, catalogRes] = await Promise.all([
        supabase
          .from('lab_orders')
          .select(`
            *,
            patient_visitations (
              visit_id,
              patients (full_name, no_rm),
              clinics (name)
            ),
            lab_analysis (*)
          `)
          .order('order_date', { ascending: false }),
        supabase.from('lab_test_catalog').select('*').eq('is_active', true)
      ]);

      if (ordersRes.error) throw ordersRes.error;
      if (catalogRes.error) throw catalogRes.error;

      orders = ordersRes.data || [];
      catalog = catalogRes.data || [];
    } catch (e) {
      console.error('Gagal memuat data:', e);
    } finally {
      loading = false;
    }
  }

  async function selectOrder(order) {
    selectedOrder = order;
    analysisResults = {};
    if (order.lab_analysis && order.lab_analysis.length > 0) {
      order.lab_analysis.forEach(a => {
        analysisResults[a.id] = { result: a.result || '', flag: a.flag || '' };
      });
    } else {
      const items = catalog.filter(c => c.category === order.category);
      if (items.length > 0) {
        items.forEach(item => {
          analysisResults[`new_${item.id}`] = {
            analysis_name: item.test_name,
            normal_value: item.normal_value,
            unit: item.unit,
            result: '',
            flag: '',
            category: item.category
          };
        });
      }
    }
  }

  async function saveResults() {
    if (!selectedOrder) return;
    saving = true;
    try {
      for (const [key, val] of Object.entries(analysisResults)) {
        if (key.startsWith('new_')) {
          if (!val.result) continue;
          await supabase.from('lab_analysis').insert({
            lab_order_id: selectedOrder.id,
            analysis_name: val.analysis_name,
            category: val.category,
            normal_value: val.normal_value,
            result: val.result,
            unit: val.unit,
            flag: val.flag
          });
        } else {
          if (!val.result) continue;
          await supabase.from('lab_analysis').update({ result: val.result, flag: val.flag }).eq('id', parseInt(key));
        }
      }

      await supabase.from('lab_orders').update({ status: 'completed', completed_at: new Date().toISOString() }).eq('id', selectedOrder.id);

      selectedOrder = null;
      await loadOrders();
    } catch (e) {
      console.error('Gagal menyimpan:', e);
    } finally {
      saving = false;
    }
  }

  function closeDetail() {
    selectedOrder = null;
    analysisResults = {};
  }

  $effect(() => {
    loadOrders();
  });
</script>

<svelte:head>
  <title>Laboratorium - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Laboratorium</h1>
    <p class="text-sm text-gray-500 mt-1">Kelola order dan hasil pemeriksaan laboratorium</p>
  </div>

  <div class="card">
    <div class="flex flex-col sm:flex-row gap-4 mb-6">
      <div class="flex-1 relative">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input type="text" bind:value={search} placeholder="Cari nama pasien..." class="input-field pl-10" />
      </div>
      <div class="flex gap-2">
        <button
          onclick={() => activeTab = 'incoming'}
          class="px-4 py-2 rounded-lg font-medium text-sm transition-colors {activeTab === 'incoming' ? 'bg-emerald-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}"
        >
          Order Masuk
        </button>
        <button
          onclick={() => activeTab = 'completed'}
          class="px-4 py-2 rounded-lg font-medium text-sm transition-colors {activeTab === 'completed' ? 'bg-emerald-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}"
        >
          Selesai
        </button>
      </div>
    </div>

    {#if loading}
      <div class="flex items-center justify-center h-64">
        <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
      </div>
    {:else if filteredOrders.length === 0}
      <div class="text-center py-12 text-gray-400">
        <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3" />
        </svg>
        <p class="font-medium">Tidak ada data ditemukan</p>
      </div>
    {:else}
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead>
            <tr>
              <th class="table-header px-4 py-3 text-left">No RM</th>
              <th class="table-header px-4 py-3 text-left">Pasien</th>
              <th class="table-header px-4 py-3 text-left">Pemeriksaan</th>
              <th class="table-header px-4 py-3 text-left">Poli</th>
              <th class="table-header px-4 py-3 text-left">Tanggal</th>
              <th class="table-header px-4 py-3 text-left">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each filteredOrders as order}
              <tr
                class="hover:bg-gray-50 cursor-pointer transition-colors"
                onclick={() => selectOrder(order)}
              >
                <td class="table-cell font-mono text-xs">{order.patient_visitations?.patients?.no_rm || '-'}</td>
                <td class="table-cell font-medium">{order.patient_visitations?.patients?.full_name || '-'}</td>
                <td class="table-cell">{order.test_name || '-'}</td>
                <td class="table-cell">{order.patient_visitations?.clinics?.name || '-'}</td>
                <td class="table-cell text-gray-500">{formatDate(order.order_date)}</td>
                <td class="table-cell">
                  {#if order.status === 'completed'}
                    <span class="badge badge-success">Selesai</span>
                  {:else if order.status === 'in_progress'}
                    <span class="badge badge-info">Dikerjakan</span>
                  {:else}
                    <span class="badge badge-warning">Ordered</span>
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

{#if selectedOrder}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={closeDetail}>
    <div class="bg-white rounded-2xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto" onclick={(e) => e.stopPropagation()}>
      <div class="p-6 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-lg font-bold text-gray-900">{selectedOrder.test_name}</h3>
            <p class="text-sm text-gray-500 mt-1">
              {selectedOrder.patient_visitations?.patients?.full_name || '-'} | {selectedOrder.patient_visitations?.patients?.no_rm || '-'}
            </p>
          </div>
          <button onclick={closeDetail} class="p-2 rounded-lg hover:bg-gray-100 transition-colors">
            <svg class="w-5 h-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
      <div class="p-6">
        {#if Object.keys(analysisResults).length === 0}
          <p class="text-center text-gray-500 py-4">Tidak ada item analisis untuk pemeriksaan ini</p>
        {:else}
          <div class="space-y-3">
            {#each Object.entries(analysisResults) as [key, item]}
              <div class="flex items-center gap-4 p-3 bg-gray-50 rounded-lg">
                <div class="flex-1">
                  <p class="text-sm font-medium text-gray-700">{item.analysis_name || key}</p>
                  <p class="text-xs text-gray-500">Normal: {item.normal_value || '-'} {item.unit || ''}</p>
                </div>
                <input
                  type="text"
                  bind:value={item.result}
                  placeholder="Hasil"
                  class="w-32 px-3 py-1.5 rounded-lg border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
                <select
                  bind:value={item.flag}
                  class="w-24 px-2 py-1.5 rounded-lg border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                >
                  <option value="">-</option>
                  <option value="high">Tinggi</option>
                  <option value="low">Rendah</option>
                  <option value="normal">Normal</option>
                </select>
              </div>
            {/each}
          </div>
        {/if}
      </div>
      <div class="p-6 border-t border-gray-200 flex justify-end gap-3">
        <button onclick={closeDetail} class="btn-secondary">Batal</button>
        <button onclick={saveResults} disabled={saving} class="btn-success">
          {#if saving}
            <span class="flex items-center gap-2">
              <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
              Menyimpan...
            </span>
          {:else}
            Simpan & Selesaikan
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}
