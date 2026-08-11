<script>
  import { supabase } from '$lib/supabase';
  import { formatDate, formatCurrency } from '$lib/utils/helpers';
  import { REPORT_TYPES } from '$lib/utils/constants';

  let reportType = $state('kunjungan');
  let dateFrom = $state(new Date().toISOString().split('T')[0]);
  let dateTo = $state(new Date().toISOString().split('T')[0]);
  let loading = $state(false);
  let reportData = $state([]);
  let reportColumns = $state([]);

  async function generateReport() {
    loading = true;
    reportData = [];
    reportColumns = [];

    try {
      switch (reportType) {
        case 'kunjungan': {
          const { data } = await supabase
            .from('patient_visitations')
            .select(`
              visit_id, visit_date, status_periksa,
              patients (full_name, no_rm, gender),
              clinics (name),
              employees (full_name)
            `)
            .gte('visit_date', dateFrom)
            .lte('visit_date', dateTo + 'T23:59:59')
            .order('visit_date');
          reportColumns = ['Tanggal', 'No RM', 'Nama Pasien', 'Poli', 'Dokter', 'Status'];
          reportData = (data || []).map(v => [
            formatDate(v.visit_date),
            v.patients?.no_rm || '-',
            v.patients?.full_name || '-',
            v.clinics?.name || '-',
            v.employees?.full_name || '-',
            v.status_periksa === '1' ? 'Selesai' : 'Menunggu'
          ]);
          break;
        }
        case 'penyakit_top10': {
          const { data } = await supabase
            .from('patient_diagnoses')
            .select(`
              diagnosis_id,
              diagnoses (code, name),
              patient_visitations!inner (visit_date)
            `);
          const filtered = (data || []).filter(d => {
            const dt = d.patient_visitations?.visit_date;
            return dt && dt >= dateFrom && dt <= dateTo + 'T23:59:59';
          });
          const counts = {};
          filtered.forEach(d => {
            const key = `${d.diagnoses?.code}|${d.diagnoses?.name}`;
            counts[key] = (counts[key] || 0) + 1;
          });
          const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, 10);
          reportColumns = ['Rank', 'Kode', 'Diagnosa', 'Jumlah'];
          reportData = sorted.map(([key, count], i) => {
            const [code, name] = key.split('|');
            return [i + 1, code, name, count];
          });
          break;
        }
        case 'sensus_harian': {
          const { data } = await supabase
            .from('patient_visitations')
            .select(`clinic_id, clinics (name), visit_date`)
            .gte('visit_date', dateFrom)
            .lte('visit_date', dateTo + 'T23:59:59');
          const counts = {};
          (data || []).forEach(v => {
            const name = v.clinics?.name || 'Lainnya';
            counts[name] = (counts[name] || 0) + 1;
          });
          reportColumns = ['Poli', 'Jumlah Kunjungan'];
          reportData = Object.entries(counts).map(([name, count]) => [name, count]);
          break;
        }
        case 'tindakan': {
          const { data } = await supabase
            .from('treatment_bills')
            .select(`
              tariffs (name, category), quantity, amount,
              patient_visitations!inner (visit_date)
            `);
          const filtered = (data || []).filter(d => {
            const dt = d.patient_visitations?.visit_date;
            return dt && dt >= dateFrom && dt <= dateTo + 'T23:59:59';
          });
          reportColumns = ['Tindakan', 'Kategori', 'Jumlah', 'Total'];
          reportData = filtered.map(b => [
            b.tariffs?.name || '-',
            b.tariffs?.category || '-',
            b.quantity,
            formatCurrency(b.amount)
          ]);
          break;
        }
        case 'pendapatan': {
          const { data } = await supabase
            .from('billing_invoices')
            .select('invoice_id, net_amount, payment_method, status, paid_at, patient_visitations (patients (full_name), clinics (name))')
            .eq('status', 'paid')
            .gte('paid_at', dateFrom)
            .lte('paid_at', dateTo + 'T23:59:59');
          reportColumns = ['Invoice', 'Pasien', 'Poli', 'Metode', 'Jumlah'];
          reportData = (data || []).map(i => [
            i.invoice_id,
            i.patient_visitations?.patients?.full_name || '-',
            i.patient_visitations?.clinics?.name || '-',
            i.payment_method?.toUpperCase() || '-',
            formatCurrency(i.net_amount)
          ]);
          break;
        }
      }
    } catch (e) {
      console.error('Gagal generate laporan:', e);
      alert('Terjadi kesalahan saat generate laporan');
    } finally {
      loading = false;
    }
  }

  function printReport() {
    window.print();
  }
</script>

<svelte:head>
  <title>Laporan - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Laporan</h1>
    <p class="text-sm text-gray-500 mt-1">Generate berbagai laporan puskesmas</p>
  </div>

  <div class="card">
    <div class="grid grid-cols-1 sm:grid-cols-4 gap-4 mb-6">
      <div>
        <label class="label">Jenis Laporan</label>
        <select bind:value={reportType} class="select-field">
          {#each Object.entries(REPORT_TYPES) as [key, label]}
            <option value={key}>{label}</option>
          {/each}
        </select>
      </div>
      <div>
        <label class="label">Dari Tanggal</label>
        <input type="date" bind:value={dateFrom} class="input-field" />
      </div>
      <div>
        <label class="label">Sampai Tanggal</label>
        <input type="date" bind:value={dateTo} class="input-field" />
      </div>
      <div class="flex items-end gap-2">
        <button onclick={generateReport} disabled={loading} class="btn-primary flex-1">
          {#if loading}
            <span class="flex items-center justify-center gap-2">
              <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
              Memproses...
            </span>
          {:else}
            Generate
          {/if}
        </button>
        {#if reportData.length > 0}
          <button onclick={printReport} class="btn-secondary">Cetak</button>
        {/if}
      </div>
    </div>

    {#if reportData.length > 0}
      <div class="border border-gray-200 rounded-xl overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr>
                {#each reportColumns as col}
                  <th class="table-header px-4 py-3 text-left">{col}</th>
                {/each}
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each reportData as row}
                <tr class="hover:bg-gray-50">
                  {#each row as cell}
                    <td class="table-cell">{cell}</td>
                  {/each}
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
        <div class="px-4 py-3 bg-gray-50 border-t border-gray-200">
          <p class="text-sm text-gray-500">Total: {reportData.length} data | Periode: {formatDate(dateFrom)} - {formatDate(dateTo)}</p>
        </div>
      </div>
    {:else if !loading}
      <div class="text-center py-12 text-gray-400">
        <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
        </svg>
        <p class="font-medium">Pilih jenis laporan dan periode</p>
        <p class="text-sm mt-1">Klik "Generate" untuk menampilkan data</p>
      </div>
    {/if}
  </div>
</div>
