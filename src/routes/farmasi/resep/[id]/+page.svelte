<script>
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { supabase } from '$lib/supabase';
  import { formatDate, formatCurrency } from '$lib/utils/helpers';

  const prescriptionId = $derived(page.params.id);

  let prescription = $state(null);
  let loading = $state(true);
  let dispensing = $state(false);

  function appPath(path) {
    return `${base}${path}`;
  }

  async function loadPrescription() {
    loading = true;
    try {
      const { data, error } = await supabase
        .from('prescriptions')
        .select(`
          *,
          patient_visitations (
            visit_id,
            patients (full_name, no_rm, phone),
            clinics (name)
          ),
          employees (full_name),
          prescription_items (
            *,
            drugs (drug_id, name, generic_name, unit, stock, sell_price)
          )
        `)
        .eq('id', prescriptionId)
        .single();

      if (error) throw error;
      prescription = data;
    } catch (e) {
      console.error('Gagal memuat resep:', e);
    } finally {
      loading = false;
    }
  }

  let totalPrice = $derived(
    prescription?.prescription_items?.reduce((sum, item) => sum + (item.total_price || 0), 0) || 0
  );

  async function dispenseAll() {
    if (!prescription) return;
    dispensing = true;
    try {
      for (const item of prescription.prescription_items) {
        if (item.is_dispensed) continue;

        const newStock = (item.drugs?.stock || 0) - item.quantity;
        if (newStock < 0) {
          alert(`Stok ${item.drugs?.name} tidak cukup! Sisa: ${item.drugs?.stock}`);
          dispensing = false;
          return;
        }

        await supabase.from('drugs').update({ stock: newStock }).eq('drug_id', item.drugs?.drug_id);

        await supabase.from('drug_stock_logs').insert({
          drug_id: item.drugs?.drug_id,
          change_type: 'out',
          quantity: item.quantity,
          reference: `Resep #${prescription.id}`,
          notes: `Dispensing untuk ${prescription.patient_visitations?.patients?.full_name}`
        });

        await supabase.from('prescription_items').update({ is_dispensed: true }).eq('id', item.id);
      }

      await supabase.from('prescriptions').update({
        status: 'dispensed',
        dispensed_at: new Date().toISOString()
      }).eq('id', prescription.id);

      alert('Berhasil didispensasi!');
      await loadPrescription();
    } catch (e) {
      console.error('Gagal dispensasi:', e);
      alert('Terjadi kesalahan saat dispensasi');
    } finally {
      dispensing = false;
    }
  }

  $effect(() => {
    if (prescriptionId) loadPrescription();
  });
</script>

<svelte:head>
  <title>Detail Resep - SMARTHEALTH</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center h-64">
    <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
  </div>
{:else if !prescription}
  <div class="text-center py-12">
    <p class="text-gray-500">Data resep tidak ditemukan</p>
    <button onclick={() => goto(appPath('/farmasi'))} class="btn-primary mt-4">Kembali</button>
  </div>
{:else}
  <div class="space-y-6">
    <div class="flex items-center gap-4">
      <button onclick={() => goto(appPath('/farmasi'))} class="p-2 rounded-lg hover:bg-gray-100 transition-colors">
        <svg class="w-5 h-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
        </svg>
      </button>
      <div class="flex-1">
        <h1 class="text-2xl font-bold text-gray-900">Detail Resep</h1>
        <p class="text-sm text-gray-500 mt-1">Informasi resep obat pasien</p>
      </div>
      {#if prescription.status === 'pending'}
        <button onclick={dispenseAll} disabled={dispensing} class="btn-success">
          {#if dispensing}
            <span class="flex items-center gap-2">
              <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
              Memproses...
            </span>
          {:else}
            Dispensasi Semua
          {/if}
        </button>
      {/if}
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="card">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Informasi Resep</h3>
        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-sm text-gray-500">Status</span>
            {#if prescription.status === 'dispensed'}
              <span class="badge badge-success">Sudah Diambil</span>
            {:else if prescription.status === 'cancelled'}
              <span class="badge badge-danger">Dibatalkan</span>
            {:else}
              <span class="badge badge-warning">Menunggu</span>
            {/if}
          </div>
          <div class="flex justify-between">
            <span class="text-sm text-gray-500">Tanggal</span>
            <span class="text-sm font-medium">{formatDate(prescription.created_at)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-sm text-gray-500">Dokter</span>
            <span class="text-sm font-medium">{prescription.employees?.full_name || '-'}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-sm text-gray-500">Tipe</span>
            <span class="text-sm font-medium capitalize">{prescription.prescription_type}</span>
          </div>
          {#if prescription.notes}
            <div>
              <span class="text-sm text-gray-500">Catatan:</span>
              <p class="text-sm mt-1">{prescription.notes}</p>
            </div>
          {/if}
        </div>
      </div>

      <div class="card">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Data Pasien</h3>
        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-sm text-gray-500">No RM</span>
            <span class="text-sm font-medium font-mono">{prescription.patient_visitations?.patients?.no_rm || '-'}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-sm text-gray-500">Nama</span>
            <span class="text-sm font-medium">{prescription.patient_visitations?.patients?.full_name || '-'}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-sm text-gray-500">Telepon</span>
            <span class="text-sm font-medium">{prescription.patient_visitations?.patients?.phone || '-'}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-sm text-gray-500">Poli</span>
            <span class="text-sm font-medium">{prescription.patient_visitations?.clinics?.name || '-'}</span>
          </div>
        </div>
      </div>
    </div>

    <div class="card">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Item Resep ({prescription.prescription_items?.length || 0})</h3>
      {#if prescription.prescription_items && prescription.prescription_items.length > 0}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr>
                <th class="table-header px-4 py-3 text-left">Obat</th>
                <th class="table-header px-4 py-3 text-left">Jumlah</th>
                <th class="table-header px-4 py-3 text-left">Dosis</th>
                <th class="table-header px-4 py-3 text-left">Frekuensi</th>
                <th class="table-header px-4 py-3 text-left">Durasi</th>
                <th class="table-header px-4 py-3 text-left">Harga</th>
                <th class="table-header px-4 py-3 text-left">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each prescription.prescription_items as item}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell">
                    <div>
                      <p class="font-medium">{item.drugs?.name || '-'}</p>
                      <p class="text-xs text-gray-500">{item.drugs?.generic_name || ''}</p>
                    </div>
                  </td>
                  <td class="table-cell">{item.quantity} {item.drugs?.unit || 'tablet'}</td>
                  <td class="table-cell">{item.dosage || '-'}</td>
                  <td class="table-cell">{item.frequency || '-'}</td>
                  <td class="table-cell">{item.duration || '-'}</td>
                  <td class="table-cell">{formatCurrency(item.total_price)}</td>
                  <td class="table-cell">
                    {#if item.is_dispensed}
                      <span class="badge badge-success">Diambil</span>
                    {:else}
                      <span class="badge badge-warning">Belum</span>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
        <div class="mt-4 pt-4 border-t border-gray-200 flex justify-end">
          <div class="text-right">
            <p class="text-sm text-gray-500">Total</p>
            <p class="text-xl font-bold text-gray-900">{formatCurrency(totalPrice)}</p>
          </div>
        </div>
      {:else}
        <div class="text-center py-8 text-gray-400">
          <p>Tidak ada item resep</p>
        </div>
      {/if}
    </div>
  </div>
{/if}
