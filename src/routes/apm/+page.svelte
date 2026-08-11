<script>
  import { supabase } from '$lib/supabase';
  import { generateQueueNumber } from '$lib/utils/helpers';

  let step = $state('welcome');
  let patient = $state(null);
  let clinics = $state([]);
  let selectedClinic = $state(null);
  let searchNik = $state('');
  let loading = $state(false);
  let queueNumber = $state('');
  let error = $state('');
  let inactivityTimer = $state(null);

  function resetToWelcome() {
    step = 'welcome';
    patient = null;
    selectedClinic = null;
    searchNik = '';
    queueNumber = '';
    error = '';
    resetInactivityTimer();
  }

  function resetInactivityTimer() {
    clearTimeout(inactivityTimer);
    inactivityTimer = setTimeout(() => {
      resetToWelcome();
    }, 30000);
  }

  function startKiosk() {
    step = 'search';
    loadClinics();
    resetInactivityTimer();
  }

  async function loadClinics() {
    try {
      const { data } = await supabase.from('clinics').select('*').eq('is_active', true).order('name');
      clinics = data || [];
    } catch (e) {
      console.error('Gagal memuat poli:', e);
    }
  }

  async function searchPatient() {
    if (!searchNik.trim()) {
      error = 'Masukkan NIK atau No RM';
      return;
    }
    loading = true;
    error = '';
    resetInactivityTimer();

    try {
      const { data, err } = await supabase
        .from('patients')
        .select('*')
        .or(`nik.eq.${searchNik},no_rm.eq.${searchNik}`)
        .single();

      if (err || !data) {
        error = 'Pasien tidak ditemukan. Silakan hubungi registrasi.';
        loading = false;
        return;
      }

      patient = data;
      step = 'select_poli';
    } catch (e) {
      error = 'Terjadi kesalahan. Silakan coba lagi.';
    } finally {
      loading = false;
    }
  }

  async function confirmQueue() {
    if (!selectedClinic || !patient) return;
    loading = true;
    resetInactivityTimer();

    try {
      const today = new Date().toISOString().split('T')[0];
      const { count } = await supabase
        .from('queue_numbers')
        .select('id', { count: 'exact', head: true })
        .eq('clinic_id', selectedClinic.clinic_id)
        .eq('queue_date', today);

      const seq = (count || 0) + 1;
      const qNum = generateQueueNumber(seq, selectedClinic.queue_prefix || 'A');

      const { error: queueErr } = await supabase.from('queue_numbers').insert({
        queue_date: today,
        queue_number: qNum,
        clinic_id: selectedClinic.clinic_id,
        patient_id: patient.patient_id,
        status: 'waiting'
      });

      if (queueErr) throw queueErr;

      const { data: visitData, error: visitErr } = await supabase.from('patient_visitations').insert({
        patient_id: patient.patient_id,
        clinic_id: selectedClinic.clinic_id,
        visit_date: new Date().toISOString(),
        queue_number: qNum,
        status_pembayaran: '0',
        status_periksa: '0',
        visit_type: 'rawat_jalan'
      }).select().single();

      if (visitErr) throw visitErr;

      await supabase.from('queue_numbers').update({ visit_id: visitData.visit_id }).eq('queue_number', qNum).eq('queue_date', today);

      queueNumber = qNum;
      step = 'printed';
      setTimeout(resetToWelcome, 15000);
    } catch (e) {
      console.error('Gagal membuat antrian:', e);
      error = 'Gagal membuat nomor antrian. Silakan hubungi petugas.';
    } finally {
      loading = false;
    }
  }

  function handleKeydown(e) {
    resetInactivityTimer();
  }
</script>

<svelte:head>
  <title>APM - Antrian Mandiri - SMARTHEALTH</title>
</svelte:head>

<div
  class="min-h-screen bg-gradient-to-br from-emerald-600 via-emerald-700 to-emerald-900 flex items-center justify-center select-none"
  onmousemove={handleKeydown}
  onkeydown={handleKeydown}
  ontouchstart={handleKeydown}
>
  {#if step === 'welcome'}
    <div class="text-center space-y-8 px-8">
      <div class="w-32 h-32 mx-auto bg-white/15 backdrop-blur-sm rounded-3xl flex items-center justify-center border border-white/20 shadow-2xl">
        <svg class="w-20 h-20 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342" />
        </svg>
      </div>
      <div>
        <h1 class="text-6xl font-bold text-white mb-4 tracking-tight">SMARTHEALTH</h1>
        <p class="text-2xl text-emerald-100 font-medium">Puskesmas Digital</p>
      </div>
      <button
        onclick={startKiosk}
        class="px-16 py-8 bg-white text-emerald-700 text-3xl font-bold rounded-3xl shadow-2xl hover:bg-emerald-50 active:scale-95 transition-all duration-200"
      >
        Ambil Nomor Antrian
      </button>
      <p class="text-emerald-200/60 text-lg">Sentuh layar untuk memulai</p>
    </div>

  {:else if step === 'search'}
    <div class="w-full max-w-xl space-y-8 px-8">
      <div class="text-center">
        <h2 class="text-4xl font-bold text-white mb-2">Identifikasi Diri</h2>
        <p class="text-xl text-emerald-100">Masukkan NIK atau No RM Anda</p>
      </div>

      <div class="bg-white rounded-3xl shadow-2xl p-8 space-y-6">
        {#if error}
          <div class="p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 text-center text-lg">{error}</div>
        {/if}

        <input
          type="text"
          bind:value={searchNik}
          onkeydown={(e) => { if (e.key === 'Enter') searchPatient(); }}
          placeholder="NIK atau No RM"
          class="w-full px-6 py-5 text-2xl text-center rounded-xl border-2 border-gray-300 focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100 outline-none transition-all"
          autofocus
        />

        <div class="flex gap-4">
          <button onclick={resetToWelcome} class="flex-1 py-5 text-xl font-semibold bg-gray-100 text-gray-700 rounded-xl hover:bg-gray-200 active:scale-95 transition-all">
            Kembali
          </button>
          <button onclick={searchPatient} disabled={loading || !searchNik.trim()} class="flex-1 py-5 text-xl font-semibold bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 active:scale-95 transition-all disabled:opacity-50">
            {loading ? 'Mencari...' : 'Cari'}
          </button>
        </div>
      </div>
    </div>

  {:else if step === 'select_poli'}
    <div class="w-full max-w-2xl space-y-8 px-8">
      <div class="text-center">
        <p class="text-xl text-emerald-100 mb-1">Halo, <span class="font-bold text-white">{patient?.full_name}</span></p>
        <h2 class="text-4xl font-bold text-white mb-2">Pilih Poli</h2>
        <p class="text-xl text-emerald-100">Pilih poli yang ingin Anda kunjungi</p>
      </div>

      <div class="bg-white rounded-3xl shadow-2xl p-8">
        {#if clinics.length === 0}
          <p class="text-center text-gray-500 text-xl py-8">Memuat poli...</p>
        {:else}
          <div class="grid grid-cols-2 gap-4">
            {#each clinics as clinic}
              <button
                onclick={() => { selectedClinic = clinic; resetInactivityTimer(); }}
                class="p-6 rounded-2xl border-2 text-left transition-all duration-200
                  {selectedClinic?.clinic_id === clinic.clinic_id
                    ? 'border-emerald-500 bg-emerald-50 ring-4 ring-emerald-100'
                    : 'border-gray-200 hover:border-emerald-300 hover:bg-gray-50'}"
              >
                <p class="text-xl font-bold text-gray-900">{clinic.name}</p>
                <p class="text-sm text-gray-500 mt-1">{clinic.description || 'Pelayanan umum'}</p>
              </button>
            {/each}
          </div>
        {/if}

        <div class="flex gap-4 mt-8">
          <button onclick={() => { step = 'search'; error = ''; }} class="flex-1 py-4 text-lg font-semibold bg-gray-100 text-gray-700 rounded-xl hover:bg-gray-200 active:scale-95 transition-all">
            Kembali
          </button>
          <button onclick={confirmQueue} disabled={!selectedClinic || loading} class="flex-1 py-4 text-lg font-semibold bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 active:scale-95 transition-all disabled:opacity-50">
            {loading ? 'Memproses...' : 'Konfirmasi'}
          </button>
        </div>
      </div>
    </div>

  {:else if step === 'printed'}
    <div class="text-center space-y-8 px-8">
      <div class="w-24 h-24 mx-auto bg-white/15 rounded-full flex items-center justify-center">
        <svg class="w-14 h-14 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>
      <div>
        <h2 class="text-5xl font-bold text-white mb-4">Nomor Antrian Anda</h2>
        <div class="text-8xl font-black text-white tracking-wider bg-white/10 inline-block px-12 py-6 rounded-3xl">
          {queueNumber}
        </div>
        <p class="text-2xl text-emerald-100 mt-6">{selectedClinic?.name}</p>
        <p class="text-lg text-emerald-200/60 mt-2">Silakan menunggu di area tunggu poli</p>
      </div>
    </div>
  {/if}

  {#if step !== 'welcome' && step !== 'printed'}
    <button
      onclick={resetToWelcome}
      class="fixed top-6 right-6 px-4 py-2 bg-white/10 text-white rounded-lg hover:bg-white/20 transition-colors text-sm"
    >
      Beranda
    </button>
  {/if}
</div>
