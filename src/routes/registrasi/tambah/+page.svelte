<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase';
  import { generateNoRegistration, generateVisitId, generateQueueNumber, debounce } from '$lib/utils/helpers';

  let loading = $state(false);
  let saving = $state(false);
  let error = $state('');
  let success = $state('');

  let searchQuery = $state('');
  let searchType = $state('nik');
  let patientFound = $state(null);
  let isNewPatient = $state(true);
  let searching = $state(false);

   let clinics = $state([]);
  let doctors = $state([]);
  let payors = $state([]);

  let form = $state({
    full_name: '',
    gender: 'L',
    date_of_birth: '',
    nik: '',
    phone: '',
    address: '',
    rt: '',
    rw: '',
    village: '',
    district: '',
    city: '',
    province: '',
    blood_type: '',
    religion: '',
    marital_status: '',
    occupation: '',
    emergency_contact_name: '',
    emergency_contact_phone: '',
    insurance_number: '',
    payor_id: '',
    clinic_id: '',
    doctor_id: '',
    description: ''
  });

  async function searchPatient() {
    if (!searchQuery.trim()) return;
    searching = true;
    patientFound = null;
    isNewPatient = true;

    try {
      let query = supabase.from('patients').select('*').limit(1);

      if (searchType === 'nik') {
        query = query.eq('nik', searchQuery.trim());
      } else if (searchType === 'no_rm') {
        query = query.eq('no_rm', searchQuery.trim());
      } else {
        query = query.or(`nik.eq.${searchQuery.trim()},no_rm.eq.${searchQuery.trim()}`);
      }

      const { data, error: err } = await query;
      if (err) throw err;

      if (data && data.length > 0) {
        patientFound = data[0];
        isNewPatient = false;
        form.full_name = patientFound.full_name;
        form.gender = patientFound.gender;
        form.date_of_birth = patientFound.date_of_birth;
        form.nik = patientFound.nik || '';
        form.phone = patientFound.phone || '';
        form.address = patientFound.address || '';
        form.rt = patientFound.rt || '';
        form.rw = patientFound.rw || '';
        form.village = patientFound.village || '';
        form.district = patientFound.district || '';
        form.city = patientFound.city || '';
        form.province = patientFound.province || '';
        form.blood_type = patientFound.blood_type || '';
        form.religion = patientFound.religion || '';
        form.marital_status = patientFound.marital_status || '';
        form.occupation = patientFound.occupation || '';
        form.emergency_contact_name = patientFound.emergency_contact_name || '';
        form.emergency_contact_phone = patientFound.emergency_contact_phone || '';
        form.insurance_number = patientFound.insurance_number || '';
        form.payor_id = patientFound.payor_id || '';
        success = `Pasien ditemukan: ${patientFound.full_name} (${patientFound.no_rm})`;
        error = '';
      } else {
        patientFound = null;
        isNewPatient = true;
        form = {
          full_name: '', gender: 'L', date_of_birth: '', nik: searchType === 'nik' ? searchQuery.trim() : '',
          phone: '', address: '', rt: '', rw: '', village: '', district: '', city: '', province: '',
          blood_type: '', religion: '', marital_status: '', occupation: '',
          emergency_contact_name: '', emergency_contact_phone: '', insurance_number: '',
          payor_id: '', clinic_id: form.clinic_id, doctor_id: form.doctor_id, description: form.description
        };
        success = 'Pasien tidak ditemukan. Silakan isi data pasien baru.';
        error = '';
      }
    } catch (e) {
      console.error('Pencarian pasien gagal:', e);
      error = 'Gagal mencari pasien: ' + e.message;
      success = '';
    } finally {
      searching = false;
    }
  }

  function resetSearch() {
    searchQuery = '';
    patientFound = null;
    isNewPatient = true;
    success = '';
    error = '';
    form = {
      full_name: '', gender: 'L', date_of_birth: '', nik: '',
      phone: '', address: '', rt: '', rw: '', village: '', district: '', city: '', province: '',
      blood_type: '', religion: '', marital_status: '', occupation: '',
      emergency_contact_name: '', emergency_contact_phone: '', insurance_number: '',
      payor_id: '', clinic_id: form.clinic_id, doctor_id: form.doctor_id, description: form.description
    };
  }

  async function loadMasterData() {
    loading = true;
    try {
      const [clinicRes, doctorRes, payorRes] = await Promise.all([
        supabase.from('clinics').select('*').eq('is_active', true).order('name'),
        supabase.from('employees').select('*').eq('role', 'dokter').eq('is_active', true).order('full_name'),
        supabase.from('payors').select('*').eq('is_active', true).order('name')
      ]);

      clinics = clinicRes.data || [];
      doctors = doctorRes.data || [];
      payors = payorRes.data || [];
    } catch (e) {
      console.error('Gagal memuat data master:', e);
    } finally {
      loading = false;
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    saving = true;
    error = '';
    success = '';

    try {
      if (!form.clinic_id) {
        throw new Error('Poli harus dipilih');
      }

      let patientId;
      let noRm;

      if (isNewPatient) {
        if (!form.full_name) throw new Error('Nama pasien harus diisi');
        if (!form.date_of_birth) throw new Error('Tanggal lahir harus diisi');

        const { count: patientCount } = await supabase
          .from('patients')
          .select('patient_id', { count: 'exact', head: true });

        noRm = 'RM' + String((patientCount || 0) + 1).padStart(5, '0');

        const { data: newPatient, error: patientErr } = await supabase
          .from('patients')
          .insert({
            no_rm: noRm,
            full_name: form.full_name,
            gender: form.gender,
            date_of_birth: form.date_of_birth,
            nik: form.nik || null,
            phone: form.phone || null,
            address: form.address || null,
            rt: form.rt || null,
            rw: form.rw || null,
            village: form.village || null,
            district: form.district || null,
            city: form.city || null,
            province: form.province || null,
            blood_type: form.blood_type || null,
            religion: form.religion || null,
            marital_status: form.marital_status || null,
            occupation: form.occupation || null,
            emergency_contact_name: form.emergency_contact_name || null,
            emergency_contact_phone: form.emergency_contact_phone || null,
            insurance_number: form.insurance_number || null,
            payor_id: form.payor_id || null
          })
          .select()
          .single();

        if (patientErr) throw patientErr;
        patientId = newPatient.patient_id;
      } else {
        patientId = patientFound.patient_id;
        noRm = patientFound.no_rm;
      }

      const selectedClinic = clinics.find(c => c.clinic_id === form.clinic_id);
      const { count: queueCount } = await supabase
        .from('queue_numbers')
        .select('id', { count: 'exact', head: true })
        .eq('clinic_id', form.clinic_id)
        .eq('queue_date', new Date().toISOString().split('T')[0]);

      const queueNumber = generateQueueNumber((queueCount || 0) + 1, selectedClinic?.queue_prefix || 'A');

      const { data: visitData, error: visitErr } = await supabase
        .from('patient_visitations')
        .insert({
          patient_id: patientId,
          clinic_id: form.clinic_id,
          doctor_id: form.doctor_id || null,
          queue_number: queueNumber,
          status_pembayaran: '0',
          status_periksa: '0',
          status_keluar: '0',
          visit_type: 'rawat_jalan',
          payor_id: form.payor_id || null,
          kd_poli_bpjs: selectedClinic?.kd_poli_bpjs || null,
          kode_antrean: selectedClinic?.kode_antrean || null,
          description: form.description || null
        })
        .select()
        .single();

      if (visitErr) throw visitErr;

      await supabase
        .from('queue_numbers')
        .insert({
          queue_number: queueNumber,
          clinic_id: form.clinic_id,
          patient_id: patientId,
          visit_id: visitData.visit_id,
          status: 'waiting'
        });

      goto('/registrasi');
    } catch (e) {
      console.error('Registrasi gagal:', e);
      error = e.message || 'Terjadi kesalahan saat menyimpan data';
    } finally {
      saving = false;
    }
  }

  onMount(() => {
    loadMasterData();
  });
</script>

<svelte:head>
  <title>Registrasi Baru - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex items-center gap-4">
    <a
      href="/registrasi"
      class="flex items-center justify-center w-10 h-10 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors"
    >
      <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
      </svg>
    </a>
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Registrasi Baru</h1>
      <p class="text-sm text-gray-500 mt-1">Daftarkan pasien untuk kunjungan baru</p>
    </div>
  </div>

  <div class="card">
    <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
      <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
      </svg>
      Cari Pasien Lama
    </h2>

    <div class="flex flex-col sm:flex-row gap-4">
      <div class="sm:w-40">
        <label for="search-type" class="label">Cari Berdasarkan</label>
        <select id="search-type" bind:value={searchType} class="select-field">
          <option value="nik">NIK</option>
          <option value="no_rm">No RM</option>
          <option value="all">NIK / No RM</option>
        </select>
      </div>
      <div class="flex-1">
        <label for="search-input" class="label">{searchType === 'nik' ? 'NIK' : 'No RM'}</label>
        <input
          id="search-input"
          type="text"
          bind:value={searchQuery}
          placeholder={searchType === 'nik' ? 'Masukkan NIK...' : 'Masukkan No RM...'}
          class="input-field"
          onkeydown={(e) => e.key === 'Enter' && searchPatient()}
        />
      </div>
      <div class="flex items-end gap-2">
        <button
          class="btn-primary flex items-center gap-2"
          onclick={searchPatient}
          disabled={searching || !searchQuery.trim()}
        >
          {#if searching}
            <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
            </svg>
            Mencari...
          {:else}
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
            </svg>
            Cari
          {/if}
        </button>
        <button class="btn-secondary" onclick={resetSearch}>
          Reset
        </button>
      </div>
    </div>

    {#if success}
      <div class="mt-4 p-4 bg-emerald-50 border border-emerald-200 rounded-xl flex items-start gap-3">
        <svg class="w-5 h-5 text-emerald-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        <p class="text-sm text-emerald-700">{success}</p>
      </div>
    {/if}
  </div>

  <form onsubmit={handleSubmit}>
    <div class="card space-y-6">
      <h2 class="text-lg font-semibold text-gray-900 flex items-center gap-2">
        <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
        </svg>
        {isNewPatient ? 'Data Pasien Baru' : 'Data Pasien'}
        {#if !isNewPatient}
          <span class="badge badge-success text-xs">Pasien Lama</span>
        {/if}
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="md:col-span-2">
          <label for="full_name" class="label">Nama Lengkap <span class="text-red-500">*</span></label>
          <input
            id="full_name"
            type="text"
            bind:value={form.full_name}
            required
            class="input-field"
            placeholder="Masukkan nama lengkap"
          />
        </div>

        <div>
          <label for="gender" class="label">Jenis Kelamin <span class="text-red-500">*</span></label>
          <select id="gender" bind:value={form.gender} class="select-field">
            <option value="L">Laki-laki</option>
            <option value="P">Perempuan</option>
          </select>
        </div>

        <div>
          <label for="date_of_birth" class="label">Tanggal Lahir <span class="text-red-500">*</span></label>
          <input
            id="date_of_birth"
            type="date"
            bind:value={form.date_of_birth}
            required
            class="input-field"
          />
        </div>

        <div>
          <label for="nik" class="label">NIK</label>
          <input
            id="nik"
            type="text"
            bind:value={form.nik}
            class="input-field"
            placeholder="Nomor Induk Kependudukan"
            maxlength="16"
          />
        </div>

        <div>
          <label for="phone" class="label">No. HP</label>
          <input
            id="phone"
            type="tel"
            bind:value={form.phone}
            class="input-field"
            placeholder="Nomor handphone"
          />
        </div>

        <div>
          <label for="blood_type" class="label">Golongan Darah</label>
          <select id="blood_type" bind:value={form.blood_type} class="select-field">
            <option value="">- Pilih -</option>
            <option value="A">A</option>
            <option value="B">B</option>
            <option value="AB">AB</option>
            <option value="O">O</option>
          </select>
        </div>

        <div>
          <label for="religion" class="label">Agama</label>
          <select id="religion" bind:value={form.religion} class="select-field">
            <option value="">- Pilih -</option>
            <option value="Islam">Islam</option>
            <option value="Kristen">Kristen</option>
            <option value="Katolik">Katolik</option>
            <option value="Hindu">Hindu</option>
            <option value="Buddha">Buddha</option>
            <option value="Konghucu">Konghucu</option>
          </select>
        </div>

        <div>
          <label for="marital_status" class="label">Status Perkawinan</label>
          <select id="marital_status" bind:value={form.marital_status} class="select-field">
            <option value="">- Pilih -</option>
            <option value="Belum Kawin">Belum Kawin</option>
            <option value="Kawin">Kawin</option>
            <option value="Cerai Hidup">Cerai Hidup</option>
            <option value="Cerai Mati">Cerai Mati</option>
          </select>
        </div>

        <div>
          <label for="occupation" class="label">Pekerjaan</label>
          <input
            id="occupation"
            type="text"
            bind:value={form.occupation}
            class="input-field"
            placeholder="Pekerjaan"
          />
        </div>

        <div class="md:col-span-2">
          <label for="address" class="label">Alamat</label>
          <textarea
            id="address"
            bind:value={form.address}
            class="input-field"
            rows="2"
            placeholder="Alamat lengkap"
          ></textarea>
        </div>

        <div>
          <label for="rt" class="label">RT</label>
          <input id="rt" type="text" bind:value={form.rt} class="input-field" placeholder="RT" />
        </div>

        <div>
          <label for="rw" class="label">RW</label>
          <input id="rw" type="text" bind:value={form.rw} class="input-field" placeholder="RW" />
        </div>

        <div>
          <label for="village" class="label">Kelurahan</label>
          <input id="village" type="text" bind:value={form.village} class="input-field" placeholder="Kelurahan" />
        </div>

        <div>
          <label for="district" class="label">Kecamatan</label>
          <input id="district" type="text" bind:value={form.district} class="input-field" placeholder="Kecamatan" />
        </div>

        <div>
          <label for="city" class="label">Kota/Kabupaten</label>
          <input id="city" type="text" bind:value={form.city} class="input-field" placeholder="Kota/Kabupaten" />
        </div>

        <div>
          <label for="province" class="label">Provinsi</label>
          <input id="province" type="text" bind:value={form.province} class="input-field" placeholder="Provinsi" />
        </div>
      </div>

      <div class="border-t border-gray-200 pt-6">
        <h3 class="text-sm font-semibold text-gray-700 mb-3">Kontak Darurat</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label for="emergency_name" class="label">Nama Kontak Darurat</label>
            <input
              id="emergency_name"
              type="text"
              bind:value={form.emergency_contact_name}
              class="input-field"
              placeholder="Nama"
            />
          </div>
          <div>
            <label for="emergency_phone" class="label">No. HP Kontak Darurat</label>
            <input
              id="emergency_phone"
              type="tel"
              bind:value={form.emergency_contact_phone}
              class="input-field"
              placeholder="Nomor handphone"
            />
          </div>
        </div>
      </div>
    </div>

    <div class="card space-y-6 mt-6">
      <h2 class="text-lg font-semibold text-gray-900 flex items-center gap-2">
        <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
        </svg>
        Data Kunjungan
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label for="clinic_id" class="label">Poli <span class="text-red-500">*</span></label>
          <select id="clinic_id" bind:value={form.clinic_id} required class="select-field">
            <option value="">- Pilih Poli -</option>
            {#each clinics as clinic}
              <option value={clinic.clinic_id}>{clinic.name}</option>
            {/each}
          </select>
        </div>

        <div>
          <label for="doctor_id" class="label">Dokter</label>
          <select id="doctor_id" bind:value={form.doctor_id} class="select-field">
            <option value="">- Pilih Dokter -</option>
            {#each doctors as doctor}
              <option value={doctor.employee_id}>{doctor.full_name} {doctor.specialization ? `(${doctor.specialization})` : ''}</option>
            {/each}
          </select>
        </div>

        <div>
          <label for="payor_id" class="label">Penanggung Biaya</label>
          <select id="payor_id" bind:value={form.payor_id} class="select-field">
            <option value="">- Pilih Penanggung -</option>
            {#each payors as payor}
              <option value={payor.payor_id}>{payor.name}</option>
            {/each}
          </select>
        </div>

        <div>
          <label for="insurance_number" class="label">No. Asuransi/BPJS</label>
          <input
            id="insurance_number"
            type="text"
            bind:value={form.insurance_number}
            class="input-field"
            placeholder="Nomor kepesertaan"
          />
        </div>

        <div class="md:col-span-2">
          <label for="description" class="label">Keterangan</label>
          <textarea
            id="description"
            bind:value={form.description}
            class="input-field"
            rows="2"
            placeholder="Keterangan kunjungan (opsional)"
          ></textarea>
        </div>
      </div>
    </div>

    {#if error}
      <div class="card mt-6 bg-red-50 border-red-200">
        <div class="flex items-start gap-3">
          <svg class="w-5 h-5 text-red-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="text-sm text-red-700">{error}</p>
        </div>
      </div>
    {/if}

    <div class="flex items-center justify-end gap-3 mt-6">
      <a href="/registrasi" class="btn-secondary">
        Batal
      </a>
      <button
        type="submit"
        disabled={saving || loading}
        class="btn-success flex items-center gap-2"
      >
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
          Simpan Registrasi
        {/if}
      </button>
    </div>
  </form>
</div>
