<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import { supabase } from '$lib/supabase';
  import { getCurrentUser, logAudit } from '$lib/auth';
  import { generateVisitId, debounce } from '$lib/utils/helpers';
  import { ADMISSION_TYPES } from '$lib/utils/constants';

  let loading = $state(true);
  let saving = $state(false);
  let error = $state('');
  let user = $state(null);

  let rooms = $state([]);
  let beds = $state([]);
  let doctors = $state([]);
  let originClinicId = $state('');

  let selectedRoom = $state('');
  let availableBeds = $derived(beds.filter(b => b.status === 'available'));

  let patientSearch = $state('');
  let patientResults = $state([]);
  let searchingPatient = $state(false);
  let selectedPatient = $state(null);
  let searchType = $state('nik');

  let form = $state({
    bed_id: '',
    admission_type: 'plan',
    expected_discharge_date: '',
    doctor_id: '',
    notes: ''
  });

  function appPath(path) {
    return `${base}${path}`;
  }

  async function loadMaster() {
    loading = true;
    try {
      const bedParam = page.url.searchParams.get('bed') || '';
      const [roomsRes, bedsRes, doctorRes, clinicRes] = await Promise.all([
        supabase.from('inpatient_rooms').select('*').eq('is_active', true).order('floor').order('name'),
        supabase.from('inpatient_beds').select('*, inpatient_rooms(name)').eq('is_active', true).eq('status', 'available').order('bed_number'),
        supabase.from('employees').select('employee_id, full_name, specialization').eq('role', 'dokter').eq('is_active', true).order('full_name'),
        supabase.from('clinics').select('clinic_id').eq('is_active', true).order('name')
      ]);

      if (roomsRes.error) throw roomsRes.error;
      if (bedsRes.error) throw bedsRes.error;
      if (doctorRes.error) throw doctorRes.error;
      if (clinicRes.error) throw clinicRes.error;

      rooms = roomsRes.data || [];
      beds = bedsRes.data || [];
      doctors = doctorRes.data || [];

      const clinics = clinicRes.data || [];
      originClinicId = clinics.find(c => c.clinic_id === 'POL-IGD')?.clinic_id || clinics[0]?.clinic_id || '';

      if (bedParam && beds.find(b => b.bed_id === bedParam)) {
        form.bed_id = bedParam;
        const bed = beds.find(b => b.bed_id === bedParam);
        selectedRoom = bed.room_id;
      }
    } catch (e) {
      console.error('Gagal memuat data master:', e);
      error = 'Gagal memuat data master: ' + e.message;
    } finally {
      loading = false;
    }
  }

  const searchPatient = debounce(async (q) => {
    if (!q || q.trim().length < 3) { patientResults = []; return; }
    searchingPatient = true;
    try {
      let query = supabase.from('patients').select('*').limit(10);
      if (searchType === 'nik') {
        query = query.or(`nik.ilike.%${q.trim()}%,no_rm.ilike.%${q.trim()}%`);
      } else {
        query = query.or(`full_name.ilike.%${q.trim()}%,no_rm.ilike.%${q.trim()}%`);
      }
      const { data } = await query;
      patientResults = data || [];
    } catch (e) {
      console.error('Gagal cari pasien:', e);
    } finally {
      searchingPatient = false;
    }
  }, 400);

  function handlePatientSearch() {
    searchPatient(patientSearch);
  }

  function selectPatient(patient) {
    selectedPatient = patient;
    patientSearch = `${patient.full_name} (${patient.no_rm})`;
    patientResults = [];
  }

  function clearPatient() {
    selectedPatient = null;
    patientSearch = '';
    patientResults = [];
  }

  function bedsOfRoom(roomId) {
    return availableBeds.filter(b => b.room_id === roomId);
  }

  async function handleSubmit() {
    error = '';
    if (!selectedPatient) {
      error = 'Pilih pasien terlebih dahulu';
      return;
    }
    if (!form.bed_id) {
      error = 'Pilih kamar dan tempat tidur terlebih dahulu';
      return;
    }
    saving = true;
    try {
      const bed = beds.find(b => b.bed_id === form.bed_id);
      if (!bed || bed.status !== 'available') {
        throw new Error('Tempat tidur sudah tidak tersedia');
      }

      const visitId = generateVisitId();
      const now = new Date().toISOString();

      const { data: visitData, error: visitErr } = await supabase
        .from('patient_visitations')
        .insert({
          visit_id: visitId,
          patient_id: selectedPatient.patient_id,
          clinic_id: originClinicId || 'POL-IGD',
          doctor_id: form.doctor_id || null,
          visit_date: now,
          status_pembayaran: '0',
          status_periksa: '0',
          status_keluar: '0',
          visit_type: 'rawat_inap',
          payor_id: selectedPatient.payor_id || null,
          in_date: now,
          description: `Rawat Inap: ${form.notes || 'Admisi pasien'}`
        })
        .select()
        .single();
      if (visitErr) throw visitErr;

      const { data: admission, error: admErr } = await supabase
        .from('inpatient_admissions')
        .insert({
          visit_id: visitId,
          patient_id: selectedPatient.patient_id,
          bed_id: form.bed_id,
          doctor_id: form.doctor_id || null,
          admission_type: form.admission_type,
          admission_date: now,
          expected_discharge_date: form.expected_discharge_date || null,
          notes: form.notes || null,
          status: 'admitted',
          created_by: user?.profile?.profilePersisted ? user.id : null
        })
        .select()
        .single();
      if (admErr) throw admErr;

      const { error: bedErr } = await supabase
        .from('inpatient_beds')
        .update({ status: 'occupied' })
        .eq('bed_id', form.bed_id);
      if (bedErr) throw bedErr;

      await logAudit('CREATE', 'inpatient_admissions', admission.admission_id, null, {
        visit_id: visitId,
        patient_id: selectedPatient.patient_id,
        bed_id: form.bed_id
      });

      goto(appPath(`/rawat-inap/${admission.admission_id}`));
    } catch (e) {
      console.error('Admisi gagal:', e);
      error = e.message || 'Gagal melakukan admisi pasien';
    } finally {
      saving = false;
    }
  }

  onMount(async () => {
    try {
      const currentUser = await getCurrentUser();
      if (currentUser) user = currentUser;
    } catch (e) {
      console.error('Auth error:', e);
    }
    await loadMaster();
  });
</script>

<svelte:head>
  <title>Admisi Rawat Inap - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex items-center gap-4">
    <a href={appPath('/rawat-inap')} class="flex items-center justify-center w-10 h-10 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors">
      <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
      </svg>
    </a>
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Admisi Pasien Rawat Inap</h1>
      <p class="text-sm text-gray-500 mt-1">Pilih pasien dan alokasikan kamar/bed</p>
    </div>
  </div>

  {#if loading}
    <div class="flex items-center justify-center h-64">
      <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
    </div>
  {:else}
    <form onsubmit={(e) => { e.preventDefault(); handleSubmit(); }} class="space-y-6">
      <!-- Pasien -->
      <div class="card space-y-4">
        <h2 class="text-lg font-semibold text-gray-900">1. Data Pasien</h2>

        {#if !selectedPatient}
          <div class="flex flex-col sm:flex-row gap-3">
            <div class="sm:w-44">
              <label class="label">Cari Berdasarkan</label>
              <select class="select-field" bind:value={searchType}>
                <option value="nik">NIK / No RM</option>
                <option value="nama">Nama</option>
              </select>
            </div>
            <div class="flex-1">
              <label class="label">Pencarian</label>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
                </svg>
                <input
                  type="text"
                  class="input-field pl-10"
                  placeholder="Ketik minimal 3 karakter..."
                  bind:value={patientSearch}
                  oninput={handlePatientSearch}
                />
              </div>
              {#if searchingPatient}
                <p class="text-xs text-gray-400 mt-1">Mencari...</p>
              {/if}
              {#if patientResults.length > 0}
                <div class="mt-2 border border-gray-200 rounded-lg max-h-56 overflow-y-auto bg-white shadow-sm">
                  {#each patientResults as patient}
                    <button
                      type="button"
                      class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-gray-50 border-b border-gray-100 last:border-0"
                      onclick={() => selectPatient(patient)}
                    >
                      <div>
                        <p class="text-sm font-medium text-gray-900">{patient.full_name}</p>
                        <p class="text-xs text-gray-500 font-mono">{patient.no_rm} {patient.nik ? `| ${patient.nik}` : ''}</p>
                      </div>
                      <span class="text-xs text-emerald-600 font-medium">Pilih</span>
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          </div>
        {:else}
          <div class="flex items-center justify-between bg-emerald-50 border border-emerald-200 rounded-xl p-4">
            <div>
              <p class="font-semibold text-emerald-900">{selectedPatient.full_name}</p>
              <p class="text-sm text-emerald-700 font-mono">{selectedPatient.no_rm} {selectedPatient.nik ? `| ${selectedPatient.nik}` : ''}</p>
            </div>
            <button type="button" class="text-sm text-red-500 hover:text-red-700" onclick={clearPatient}>Ganti</button>
          </div>
        {/if}
      </div>

      <!-- Kamar & Bed -->
      <div class="card space-y-4">
        <h2 class="text-lg font-semibold text-gray-900">2. Alokasi Kamar & Bed</h2>

        <div>
          <label class="label">Pilih Kamar</label>
          <select class="select-field" bind:value={selectedRoom}>
            <option value="">- Pilih Kamar -</option>
            {#each rooms as room}
              <option value={room.room_id} disabled={bedsOfRoom(room.room_id).length === 0}>
                {room.name} ({room.class} - Lantai {room.floor}) {bedsOfRoom(room.room_id).length} bed tersedia
              </option>
            {/each}
          </select>
        </div>

        {#if selectedRoom}
          <div>
            <label class="label">Pilih Tempat Tidur</label>
            <div class="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 gap-3">
              {#each bedsOfRoom(selectedRoom) as bed}
                <button
                  type="button"
                  class="aspect-square rounded-xl border-2 flex items-center justify-center font-bold text-sm transition-all
                    {form.bed_id === bed.bed_id
                      ? 'bg-emerald-600 border-emerald-600 text-white shadow-md'
                      : 'bg-emerald-50 border-emerald-300 text-emerald-700 hover:bg-emerald-100'}"
                  onclick={() => form.bed_id = bed.bed_id}
                >
                  {bed.bed_number}
                </button>
              {/each}
            </div>
            {#if bedsOfRoom(selectedRoom).length === 0}
              <p class="text-sm text-amber-600 mt-2">Tidak ada bed tersedia di kamar ini.</p>
            {/if}
          </div>
        {:else}
          <p class="text-sm text-gray-400">Pilih kamar untuk melihat ketersediaan tempat tidur.</p>
        {/if}

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="label">Jenis Admisi</label>
            <select class="select-field" bind:value={form.admission_type}>
              {#each Object.entries(ADMISSION_TYPES) as [value, label]}
                <option value={value}>{label}</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Perkiraan Pulang</label>
            <input type="date" class="input-field" bind:value={form.expected_discharge_date} />
          </div>
          <div>
            <label class="label">Dokter Penanggung Jawab</label>
            <select class="select-field" bind:value={form.doctor_id}>
              <option value="">- Pilih Dokter -</option>
              {#each doctors as doctor}
                <option value={doctor.employee_id}>{doctor.full_name}{doctor.specialization ? ` (${doctor.specialization})` : ''}</option>
              {/each}
            </select>
          </div>
        </div>

        <div>
          <label class="label">Keterangan Admisi</label>
          <textarea class="input-field" rows="2" bind:value={form.notes} placeholder="Diagnosis masuk, kondisi pasien, dll."></textarea>
        </div>
      </div>

      {#if error}
        <div class="card bg-red-50 border-red-200">
          <div class="flex items-start gap-3">
            <svg class="w-5 h-5 text-red-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p class="text-sm text-red-700">{error}</p>
          </div>
        </div>
      {/if}

      <div class="flex items-center justify-end gap-3">
        <a href={appPath('/rawat-inap')} class="btn-secondary">Batal</a>
        <button type="submit" class="btn-success flex items-center gap-2" disabled={saving}>
          {#if saving}
            <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
            </svg>
            Menyimpan...
          {:else}
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
            </svg>
            Konfirmasi Admisi
          {/if}
        </button>
      </div>
    </form>
  {/if}
</div>
