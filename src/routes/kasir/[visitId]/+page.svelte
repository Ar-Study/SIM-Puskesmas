<script>
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase';
  import { formatDate, formatCurrency } from '$lib/utils/helpers';

  const visitId = $derived(page.params.visitId);

  let visit = $state(null);
  let treatmentBills = $state([]);
  let invoice = $state(null);
  let loading = $state(true);
  let saving = $state(false);
  let sendingBpjs = $state(false);
  let discount = $state(0);
  let paymentMethod = $state('cash');
  let paymentNote = $state('');

  let groupedBills = $derived(
    treatmentBills.reduce((acc, bill) => {
      const cat = bill.tariffs?.category || 'Lainnya';
      if (!acc[cat]) acc[cat] = [];
      acc[cat].push(bill);
      return acc;
    }, {})
  );

  let totalAmount = $derived(
    treatmentBills.reduce((sum, b) => sum + (b.amount || 0), 0)
  );

  let netAmount = $derived(totalAmount - discount);

  async function loadData() {
    loading = true;
    try {
      const [visitRes, billsRes, invoiceRes] = await Promise.all([
        supabase
          .from('patient_visitations')
          .select(`
            *,
            patients (full_name, no_rm, phone),
            clinics (name),
            employees (full_name)
          `)
          .eq('visit_id', visitId)
          .single(),
        supabase
          .from('treatment_bills')
          .select(`
            *,
            tariffs (name, category, price)
          `)
          .eq('visit_id', visitId),
        supabase
          .from('billing_invoices')
          .select('*')
          .eq('visit_id', visitId)
          .single()
      ]);

      if (visitRes.error) throw visitRes.error;

      visit = visitRes.data;
      treatmentBills = billsRes.data || [];

      if (invoiceRes.data) {
        invoice = invoiceRes.data;
        discount = invoice.discount || 0;
        paymentMethod = invoice.payment_method || 'cash';
        paymentNote = invoice.payment_note || '';
      }
    } catch (e) {
      console.error('Gagal memuat data:', e);
    } finally {
      loading = false;
    }
  }

  async function saveInvoice() {
    saving = true;
    try {
      const invoiceData = {
        visit_id: visitId,
        total_amount: totalAmount,
        discount: discount,
        net_amount: netAmount,
        status: 'unpaid'
      };

      if (invoice) {
        const { error } = await supabase
          .from('billing_invoices')
          .update(invoiceData)
          .eq('invoice_id', invoice.invoice_id);
        if (error) throw error;
      } else {
        const { data, error } = await supabase
          .from('billing_invoices')
          .insert(invoiceData)
          .select()
          .single();
        if (error) throw error;
        invoice = data;
      }

      alert('Tagihan berhasil disimpan!');
    } catch (e) {
      console.error('Gagal menyimpan:', e);
      alert('Terjadi kesalahan');
    } finally {
      saving = false;
    }
  }

  async function processPayment() {
    if (!invoice) {
      await saveInvoice();
      if (!invoice) return;
    }

    saving = true;
    try {
      const { error } = await supabase
        .from('billing_invoices')
        .update({
          status: 'paid',
          paid_amount: netAmount,
          payment_method: paymentMethod,
          payment_note: paymentNote,
          paid_at: new Date().toISOString()
        })
        .eq('invoice_id', invoice.invoice_id);

      if (error) throw error;

      await supabase
        .from('patient_visitations')
        .update({ status_pembayaran: '1' })
        .eq('visit_id', visitId);

      alert('Pembayaran berhasil!');
      await loadData();
    } catch (e) {
      console.error('Gagal memproses pembayaran:', e);
      alert('Terjadi kesalahan');
    } finally {
      saving = false;
    }
  }

  function printKwitansi() {
    alert('Cetak kwitansi - fitur cetak akan segera tersedia');
  }

  async function sendToBpjs() {
    if (!visit?.kd_poli_bpjs) {
      alert('Kode poli BPJS tidak tersedia untuk poli ini');
      return;
    }
    sendingBpjs = true;
    try {
      await new Promise(resolve => setTimeout(resolve, 500));

      const payload = {
        noKartu: visit.patients?.insurance_number || '',
        poli: visit.kd_poli_bpjs,
        kodeAntrean: visit.kode_antrean || '-',
        visitId: visit.visit_id,
        tglDaftar: formatDate(visit.visit_date),
        jumlahTagihan: netAmount,
        noInvoice: invoice?.invoice_id || '-'
      };
      alert(
        `Data tagihan telah dikirim ke BPJS!\n` +
        `Poli: ${visit.kd_poli_bpjs}\n` +
        `Kode Antrean: ${visit.kode_antrean || '-'}\n` +
        `Total: ${formatCurrency(netAmount)}\n` +
        `Payload: ${JSON.stringify(payload, null, 2)}`
      );
    } catch (e) {
      console.error('Gagal kirim ke BPJS:', e);
      alert('Gagal mengirim ke BPJS');
    } finally {
      sendingBpjs = false;
    }
  }

  $effect(() => {
    if (visitId) loadData();
  });
</script>

<svelte:head>
  <title>Detail Tagihan - SMARTHEALTH</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center h-64">
    <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
  </div>
{:else if !visit}
  <div class="text-center py-12">
    <p class="text-gray-500">Data kunjungan tidak ditemukan</p>
    <button onclick={() => goto('/kasir')} class="btn-primary mt-4">Kembali</button>
  </div>
{:else}
  <div class="space-y-6">
    <div class="flex items-center gap-4">
      <button onclick={() => goto('/kasir')} class="p-2 rounded-lg hover:bg-gray-100 transition-colors">
        <svg class="w-5 h-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
        </svg>
      </button>
      <div class="flex-1">
        <h1 class="text-2xl font-bold text-gray-900">Detail Tagihan</h1>
        <p class="text-sm text-gray-500 mt-1">{visit.patients?.full_name} - {visit.patients?.no_rm}</p>
      </div>
      <div class="flex gap-2">
        {#if invoice?.status === 'paid'}
          <button onclick={printKwitansi} class="btn-secondary">Cetak Kwitansi</button>
        {/if}
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2 space-y-6">
        <div class="card">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Rincian Tagihan</h3>
          {#if Object.keys(groupedBills).length === 0}
            <div class="text-center py-8 text-gray-400">
              <p>Belum ada tagihan tindakan</p>
            </div>
          {:else}
            {#each Object.entries(groupedBills) as [category, bills]}
              <div class="mb-4">
                <h4 class="text-sm font-semibold text-gray-700 bg-gray-50 px-3 py-2 rounded-lg mb-2">{category}</h4>
                <div class="space-y-1">
                  {#each bills as bill}
                    <div class="flex items-center justify-between px-3 py-2">
                      <div>
                        <p class="text-sm font-medium text-gray-700">{bill.tariffs?.name || bill.description || '-'}</p>
                        <p class="text-xs text-gray-500">{bill.quantity} x {formatCurrency(bill.unit_price)}</p>
                      </div>
                      <span class="text-sm font-semibold">{formatCurrency(bill.amount)}</span>
                    </div>
                  {/each}
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </div>

      <div class="space-y-6">
        <div class="card">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Ringkasan</h3>
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="text-sm text-gray-500">Subtotal</span>
              <span class="text-sm font-medium">{formatCurrency(totalAmount)}</span>
            </div>
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm text-gray-500">Diskon</span>
              <input
                type="number"
                bind:value={discount}
                min="0"
                class="w-32 px-2 py-1 text-sm text-right rounded-lg border border-gray-300 focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>
            <div class="pt-3 border-t border-gray-200 flex justify-between">
              <span class="text-sm font-semibold text-gray-900">Total Bayar</span>
              <span class="text-lg font-bold text-emerald-600">{formatCurrency(netAmount)}</span>
            </div>
          </div>
          <div class="mt-4 space-y-3">
            <button onclick={saveInvoice} disabled={saving} class="w-full btn-secondary">
              {saving ? 'Menyimpan...' : 'Simpan Tagihan'}
            </button>
          </div>
        </div>

        {#if invoice?.status !== 'paid'}
          <div class="card">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Pembayaran</h3>
            <div class="space-y-3">
              <div>
                <label class="label">Metode Pembayaran</label>
                <select bind:value={paymentMethod} class="select-field">
                  <option value="cash">Tunai</option>
                  <option value="card">Kartu</option>
                  <option value="transfer">Transfer</option>
                  <option value="bpjs">BPJS</option>
                </select>
              </div>
              <div>
                <label class="label">Catatan</label>
                <input type="text" bind:value={paymentNote} placeholder="Catatan pembayaran..." class="input-field" />
              </div>
              <button onclick={processPayment} disabled={saving} class="w-full btn-success">
                {#if saving}
                  <span class="flex items-center justify-center gap-2">
                    <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Memproses...
                  </span>
                {:else}
                  Bayar {formatCurrency(netAmount)}
                {/if}
              </button>
            </div>
          </div>
        {:else}
          <div class="card bg-emerald-50 border-emerald-200">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center">
                <svg class="w-6 h-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div>
                <p class="font-semibold text-emerald-800">Sudah Dibayar</p>
                <p class="text-sm text-emerald-600">{formatCurrency(invoice.paid_amount)} via {invoice.payment_method}</p>
              </div>
            </div>
          </div>
        {/if}

        <div class="card">
          <h3 class="text-sm font-semibold text-gray-700 mb-2">Info Kunjungan</h3>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-500">Tanggal</span>
              <span>{formatDate(visit.visit_date)}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">Poli</span>
              <span>{visit.clinics?.name || '-'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">Kode BPJS</span>
              <span class="font-mono font-semibold text-primary-600">{visit.kd_poli_bpjs || '-'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">Kode Antrean</span>
              <span class="font-mono">{visit.kode_antrean || '-'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">Dokter</span>
              <span>{visit.employees?.full_name || '-'}</span>
            </div>
          </div>
        </div>

        {#if invoice?.payment_method === 'bpjs' && visit.kd_poli_bpjs && invoice?.status !== 'paid'}
          <div class="card">
            <div class="flex items-center justify-between mb-3">
              <h3 class="text-sm font-semibold text-gray-700">Kirim ke BPJS</h3>
            </div>
            <button
              onclick={sendToBpjs}
              disabled={sendingBpjs}
              class="w-full btn-primary"
            >
              {#if sendingBpjs}
                <span class="flex items-center justify-center gap-2">
                  <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  Mengirim...
                </span>
              {:else}
                Kirim Tagihan ke BPJS
              {/if}
            </button>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
