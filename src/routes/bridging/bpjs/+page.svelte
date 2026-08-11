<script>
  import { supabase } from '$lib/supabase';
  import { formatDate } from '$lib/utils/helpers';

  let search = $state('');
  let patient = $state(null);
  let eligibility = $state(null);
  let loading = $state(false);
  let error = $state('');
  let seps = $state([]);

  const mockEligibility = {
    status: true,
    data: {
      noKartu: '-',
      nama: '-',
      tglLahir: '-',
      jenisKelamin: '-',
      tmtBerlaku: '-',
      statusPeserta: 'AKTIF',
      namaProvider: 'PUSKESMAS KOTA',
      tipePeserta: 'PNS',
      golonganPeserta: '-',
      kelasRawat: 'II'
    }
  };

  async function searchByBpjs() {
    if (!search.trim()) {
      error = 'Masukkan No BPJS';
      return;
    }
    loading = true;
    error = '';
    patient = null;
    eligibility = null;
    seps = [];

    try {
      const { data, err } = await supabase
        .from('patients')
        .select('*')
        .eq('insurance_number', search)
        .single();

      if (err || !data) {
        error = 'Pasien dengan No BPJS tersebut tidak ditemukan';
        loading = false;
        return;
      }

      patient = data;

      eligibility = {
        ...mockEligibility,
        data: {
          ...mockEligibility.data,
          noKartu: data.insurance_number || search,
          nama: data.full_name,
          tglLahir: data.date_of_birth,
          jenisKelamin: data.gender === 'L' ? 'LAKI-LAKI' : 'PEREMPUAN'
        }
      };

      const { data: visits } = await supabase
        .from('patient_visitations')
        .select('*')
        .eq('patient_id', data.patient_id)
        .order('visit_date', { ascending: false })
        .limit(5);

      seps = visits || [];
    } catch (e) {
      console.error('Gagal mencari:', e);
      error = 'Terjadi kesalahan saat pencarian';
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Bridging BPJS - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Bridging BPJS</h1>
    <p class="text-sm text-gray-500 mt-1">Integrasi dengan sistem BPJS Kesehatan</p>
  </div>

  <div class="card bg-amber-50 border-amber-200">
    <div class="flex items-start gap-3">
      <svg class="w-5 h-5 text-amber-600 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
      </svg>
      <div>
        <p class="text-sm font-semibold text-amber-800">Integrasi BPJS (Mock)</p>
        <p class="text-sm text-amber-700">Integrasi API BPJS yang sebenarnya akan ditambahkan di versi berikutnya. Saat ini menggunakan data simulasi.</p>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="flex gap-4 mb-6">
      <div class="flex-1 relative">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          type="text"
          bind:value={search}
          onkeydown={(e) => { if (e.key === 'Enter') searchByBpjs(); }}
          placeholder="Masukkan No BPJS..."
          class="input-field pl-10"
        />
      </div>
      <button onclick={searchByBpjs} disabled={loading} class="btn-primary">
        {loading ? 'Mencari...' : 'Cari'}
      </button>
    </div>

    {#if error}
      <div class="p-4 bg-red-50 border border-red-200 rounded-xl flex items-start gap-3 mb-6">
        <svg class="w-5 h-5 text-red-500 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-sm text-red-600">{error}</p>
      </div>
    {/if}

    {#if eligibility}
      <div class="mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Informasi Eligibilitas</h3>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div class="p-3 bg-gray-50 rounded-lg">
            <p class="text-xs text-gray-500">No Kartu</p>
            <p class="text-sm font-semibold">{eligibility.data.noKartu}</p>
          </div>
          <div class="p-3 bg-gray-50 rounded-lg">
            <p class="text-xs text-gray-500">Nama</p>
            <p class="text-sm font-semibold">{eligibility.data.nama}</p>
          </div>
          <div class="p-3 bg-gray-50 rounded-lg">
            <p class="text-xs text-gray-500">Tgl Lahir</p>
            <p class="text-sm font-semibold">{formatDate(eligibility.data.tglLahir)}</p>
          </div>
          <div class="p-3 bg-gray-50 rounded-lg">
            <p class="text-xs text-gray-500">Jenis Kelamin</p>
            <p class="text-sm font-semibold">{eligibility.data.jenisKelamin}</p>
          </div>
          <div class="p-3 bg-gray-50 rounded-lg">
            <p class="text-xs text-gray-500">Status</p>
            <p class="text-sm font-semibold"><span class="badge badge-success">{eligibility.data.statusPeserta}</span></p>
          </div>
          <div class="p-3 bg-gray-50 rounded-lg">
            <p class="text-xs text-gray-500">Tipe Peserta</p>
            <p class="text-sm font-semibold">{eligibility.data.tipePeserta}</p>
          </div>
          <div class="p-3 bg-gray-50 rounded-lg">
            <p class="text-xs text-gray-500">Kelas Rawat</p>
            <p class="text-sm font-semibold">{eligibility.data.kelasRawat}</p>
          </div>
          <div class="p-3 bg-gray-50 rounded-lg">
            <p class="text-xs text-gray-500">Provider</p>
            <p class="text-sm font-semibold">{eligibility.data.namaProvider}</p>
          </div>
        </div>
      </div>
    {/if}

    {#if seps.length > 0}
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Riwayat Kunjungan</h3>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr>
                <th class="table-header px-4 py-3 text-left">Tanggal</th>
                <th class="table-header px-4 py-3 text-left">Poli</th>
                <th class="table-header px-4 py-3 text-left">Status Periksa</th>
                <th class="table-header px-4 py-3 text-left">Status Bayar</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each seps as s}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell">{formatDate(s.visit_date)}</td>
                  <td class="table-cell">{s.clinic_id}</td>
                  <td class="table-cell">
                    <span class="badge {s.status_periksa === '1' ? 'badge-success' : 'badge-warning'}">
                      {s.status_periksa === '1' ? 'Selesai' : 'Menunggu'}
                    </span>
                  </td>
                  <td class="table-cell">
                    <span class="badge {s.status_pembayaran === '1' ? 'badge-success' : 'badge-warning'}">
                      {s.status_pembayaran === '1' ? 'Lunas' : 'Belum'}
                    </span>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/if}

    {#if !eligibility && !loading && !error}
      <div class="text-center py-12 text-gray-400">
        <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <p class="font-medium">Masukkan No BPJS untuk mencari data pasien</p>
      </div>
    {/if}
  </div>
</div>
