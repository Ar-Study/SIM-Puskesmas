<script>
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { getCurrentUser, logAudit } from '$lib/auth';
  import { formatDate, formatDateTime, calculateAge } from '$lib/utils/helpers';
  import { NURSING_SHIFTS, ADMISSION_TYPES, DISCHARGE_CONDITIONS } from '$lib/utils/constants';
  import VitalChart from '$lib/components/VitalChart.svelte';

  let admissionId = $derived(page.params.admissionId);

  let loading = $state(true);
  let saving = $state(false);
  let activeTab = $state('observasi');
  let user = $state(null);
  let profile = $state(null);
  let toast = $state({ show: false, message: '', type: 'success' });

  let admission = $state(null);
  let patient = $state(null);
  let bed = $state(null);
  let room = $state(null);
  let visit = $state(null);

  // Observasi tanda vital
  let vitals = $state([]);
  let vitalForm = $state({
    observed_at: '',
    blood_pressure_sistolik: '',
    blood_pressure_diastolik: '',
    heart_rate: '',
    temperature: '',
    respiratory_rate: '',
    spo2: '',
    gcs: '',
    weight: '',
    notes: ''
  });

  // Asuhan keperawatan
  let carePlans = $state([]);
  let careForm = $state({
    care_date: new Date().toISOString().split('T')[0],
    shift: 'pagi',
    subjective: '',
    objective: '',
    nursing_diagnosis: '',
    goal: '',
    intervention: '',
    implementation: '',
    evaluation: ''
  });

  // Pulang
  let dischargeForm = $state({ discharge_condition: 'sembuh', discharge_summary: '' });
  let showDischargeModal = $state(false);

  const tabs = [
    { id: 'observasi', label: 'Observasi Tanda Vital', icon: 'activity' },
    { id: 'asuhan', label: 'Asuhan Keperawatan', icon: 'clipboard' },
    { id: 'ringkasan', label: 'Ringkasan', icon: 'document' }
  ];

  function appPath(path) {
    return `${base}${path}`;
  }

  function showToast(message, type = 'success') {
    toast = { show: true, message, type };
    setTimeout(() => { toast.show = false; }, 3500);
  }

  async function loadAdmission() {
    try {
      const { data, error } = await supabase
        .from('inpatient_admissions')
        .select('*, patients(*), inpatient_beds(*, inpatient_rooms(*)), patient_visitations(*)')
        .eq('admission_id', admissionId)
        .single();
      if (error) throw error;
      admission = data;
      patient = data.patients;
      bed = data.inpatient_beds;
      room = data.inpatient_beds?.inpatient_rooms;
      visit = data.patient_visitations;
    } catch (e) {
      console.error('Gagal memuat data admisi:', e);
      showToast('Admisi tidak ditemukan', 'error');
    }
  }

  async function loadVitals() {
    try {
      const { data } = await supabase
        .from('vital_sign_observations')
        .select('*')
        .eq('admission_id', admissionId)
        .order('observed_at', { ascending: true });
      vitals = data || [];
    } catch (e) {
      console.error('Gagal memuat observasi:', e);
    }
  }

  async function loadCarePlans() {
    try {
      const { data } = await supabase
        .from('nursing_care_plans')
        .select('*')
        .eq('admission_id', admissionId)
        .order('care_date', { ascending: false })
        .order('created_at', { ascending: false });
      carePlans = data || [];
    } catch (e) {
      console.error('Gagal memuat asuhan:', e);
    }
  }

  const vitalsDerived = $derived.by(() => {
    if (vitals.length === 0) return [];
    return [...vitals].sort((a, b) => new Date(a.observed_at) - new Date(b.observed_at));
  });

  const careGroups = $derived.by(() => {
    const groups = new Map();
    for (const c of carePlans) {
      const key = c.care_date;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(c);
    }
    return [...groups.entries()];
  });

  async function addVital() {
    saving = true;
    try {
      const payload = {
        admission_id: admissionId,
        visit_id: visit?.visit_id || null,
        observed_at: vitalForm.observed_at ? new Date(vitalForm.observed_at).toISOString() : new Date().toISOString(),
        blood_pressure_sistolik: vitalForm.blood_pressure_sistolik ? Number(vitalForm.blood_pressure_sistolik) : null,
        blood_pressure_diastolik: vitalForm.blood_pressure_diastolik ? Number(vitalForm.blood_pressure_diastolik) : null,
        heart_rate: vitalForm.heart_rate ? Number(vitalForm.heart_rate) : null,
        temperature: vitalForm.temperature ? Number(vitalForm.temperature) : null,
        respiratory_rate: vitalForm.respiratory_rate ? Number(vitalForm.respiratory_rate) : null,
        spo2: vitalForm.spo2 ? Number(vitalForm.spo2) : null,
        gcs: vitalForm.gcs ? Number(vitalForm.gcs) : null,
        weight: vitalForm.weight ? Number(vitalForm.weight) : null,
        notes: vitalForm.notes || null,
        created_by: profile?.profilePersisted ? profile.id : null
      };

      const { data, error } = await supabase
        .from('vital_sign_observations')
        .insert(payload)
        .select()
        .single();
      if (error) throw error;

      vitals = [...vitals, data];
      vitalForm = {
        observed_at: '', blood_pressure_sistolik: '', blood_pressure_diastolik: '',
        heart_rate: '', temperature: '', respiratory_rate: '', spo2: '', gcs: '',
        weight: '', notes: ''
      };
      await logAudit('CREATE', 'vital_sign_observations', data.id, null, payload);
      showToast('Observasi tanda vital tersimpan');
    } catch (e) {
      console.error('Gagal simpan observasi:', e);
      showToast('Gagal menyimpan observasi: ' + e.message, 'error');
    } finally {
      saving = false;
    }
  }

  async function deleteVital(id) {
    try {
      const { error } = await supabase
        .from('vital_sign_observations')
        .delete()
        .eq('id', id);
      if (error) throw error;
      vitals = vitals.filter(v => v.id !== id);
      await logAudit('DELETE', 'vital_sign_observations', id);
      showToast('Data observasi dihapus');
    } catch (e) {
      console.error('Gagal hapus observasi:', e);
      showToast('Gagal menghapus observasi', 'error');
    }
  }

  async function addCarePlan() {
    saving = true;
    try {
      const payload = {
        admission_id: admissionId,
        visit_id: visit?.visit_id || null,
        care_date: careForm.care_date || new Date().toISOString().split('T')[0],
        shift: careForm.shift,
        subjective: careForm.subjective || null,
        objective: careForm.objective || null,
        nursing_diagnosis: careForm.nursing_diagnosis || null,
        goal: careForm.goal || null,
        intervention: careForm.intervention || null,
        implementation: careForm.implementation || null,
        evaluation: careForm.evaluation || null,
        created_by: profile?.profilePersisted ? profile.id : null
      };

      const { data, error } = await supabase
        .from('nursing_care_plans')
        .insert(payload)
        .select()
        .single();
      if (error) throw error;

      carePlans = [data, ...carePlans];
      careForm = {
        care_date: new Date().toISOString().split('T')[0],
        shift: 'pagi', subjective: '', objective: '', nursing_diagnosis: '',
        goal: '', intervention: '', implementation: '', evaluation: ''
      };
      await logAudit('CREATE', 'nursing_care_plans', data.id, null, payload);
      showToast('Asuhan keperawatan tersimpan');
    } catch (e) {
      console.error('Gagal simpan asuhan:', e);
      showToast('Gagal menyimpan asuhan: ' + e.message, 'error');
    } finally {
      saving = false;
    }
  }

  async function deleteCarePlan(id) {
    try {
      const { error } = await supabase
        .from('nursing_care_plans')
        .delete()
        .eq('id', id);
      if (error) throw error;
      carePlans = carePlans.filter(c => c.id !== id);
      await logAudit('DELETE', 'nursing_care_plans', id);
      showToast('Catatan asuhan dihapus');
    } catch (e) {
      console.error('Gagal hapus asuhan:', e);
      showToast('Gagal menghapus asuhan', 'error');
    }
  }

  async function handleDischarge() {
    if (!dischargeForm.discharge_condition) return;
    saving = true;
    try {
      const now = new Date().toISOString();

      const { error: admErr } = await supabase
        .from('inpatient_admissions')
        .update({
          status: 'discharged',
          discharge_date: now,
          discharge_condition: dischargeForm.discharge_condition,
          discharge_summary: dischargeForm.discharge_summary || null,
          updated_at: now
        })
        .eq('admission_id', admissionId);
      if (admErr) throw admErr;

      if (bed) {
        const { error: bedErr } = await supabase
          .from('inpatient_beds')
          .update({ status: 'available' })
          .eq('bed_id', bed.bed_id);
        if (bedErr) throw bedErr;
      }

      if (visit) {
        const { error: visitErr } = await supabase
          .from('patient_visitations')
          .update({ status_keluar: '1', exit_date: now, updated_at: now })
          .eq('visit_id', visit.visit_id);
        if (visitErr) throw visitErr;
      }

      await logAudit('UPDATE', 'inpatient_admissions', admissionId, null, { status: 'discharged', discharge_condition: dischargeForm.discharge_condition });

      showDischargeModal = false;
      showToast('Pasien berhasil dipulangkan. Bed kini tersedia.');
      goto(appPath('/rawat-inap'));
    } catch (e) {
      console.error('Gagal proses pulang:', e);
      showToast('Gagal memproses kepulangan: ' + e.message, 'error');
    } finally {
      saving = false;
    }
  }

  const isActive = $derived(admission?.status === 'admitted');

  onMount(async () => {
    try {
      const currentUser = await getCurrentUser();
      if (currentUser) {
        user = currentUser;
        profile = currentUser.profile;
      }
    } catch (e) {
      console.error('Auth error:', e);
    }

    await loadAdmission();
    if (!admission) {
      loading = false;
      return;
    }

    await Promise.all([loadVitals(), loadCarePlans()]);
    loading = false;
  });
</script>

<svelte:head>
  <title>Detail Rawat Inap - SMARTHEALTH</title>
</svelte:head>

{#if toast.show}
  <div class="fixed top-4 right-4 z-50 animate-in">
    <div class="flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg text-sm font-medium
      {toast.type === 'success' ? 'bg-emerald-600 text-white' : 'bg-red-600 text-white'}">
      {#if toast.type === 'success'}
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
        </svg>
      {:else}
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      {/if}
      {toast.message}
    </div>
  </div>
{/if}

{#if loading}
  <div class="flex items-center justify-center h-[60vh]">
    <div class="flex flex-col items-center gap-4">
      <div class="w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
      <p class="text-sm text-gray-500">Memuat data rawat inap...</p>
    </div>
  </div>
{:else if !admission}
  <div class="card text-center py-12">
    <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
    </svg>
    <h3 class="text-lg font-semibold text-gray-700">Admisi tidak ditemukan</h3>
    <button class="btn-primary mt-4" onclick={() => goto(appPath('/rawat-inap'))}>Kembali ke Rawat Inap</button>
  </div>
{:else}
  <div class="space-y-4">
    <!-- Header -->
    <div class="card">
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div class="flex items-center gap-4">
          <div class="w-14 h-14 rounded-xl bg-emerald-100 flex items-center justify-center flex-shrink-0">
            <span class="text-lg font-bold text-emerald-700">
              {patient?.full_name?.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2) || '??'}
            </span>
          </div>
          <div>
            <h1 class="text-xl font-bold text-gray-900">{patient?.full_name || '-'}</h1>
            <div class="flex flex-wrap items-center gap-x-4 gap-y-1 mt-1 text-sm text-gray-500">
              <span>RM: {patient?.no_rm || '-'}</span>
              <span>|</span>
              <span>{patient?.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</span>
              <span>|</span>
              <span>{calculateAge(patient?.date_of_birth)}</span>
              <span>|</span>
              <span class="flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 9.75c-2.551 0-5.056.2-7.5.582V21M3 21h18M12 6.75h.008v.008H12V6.75Z" />
                </svg>
                {room?.name || '-'} - Bed {bed?.bed_number || '-'}
              </span>
            </div>
          </div>
        </div>
        <div class="flex items-center gap-2">
          {#if isActive}
            <span class="badge badge-success">
              <span class="w-2 h-2 bg-emerald-500 rounded-full animate-pulse mr-1.5 inline-block"></span>
              Dirawat
            </span>
            <button class="btn-danger btn-sm" onclick={() => showDischargeModal = true}>
              <svg class="w-4 h-4 mr-1.5 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
              </svg>
              Proses Pulang
            </button>
          {:else}
            <span class="badge badge-gray">
              {DISCHARGE_CONDITIONS[admission.discharge_condition] || 'Sudah Pulang'}
            </span>
          {/if}
          <button class="btn-secondary btn-sm" onclick={() => goto(appPath('/rawat-inap'))}>
            <svg class="w-4 h-4 mr-1.5 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
            </svg>
            Kembali
          </button>
        </div>
      </div>

      <div class="flex flex-wrap gap-x-8 gap-y-2 mt-4 pt-4 border-t border-gray-100 text-sm">
        <div>
          <p class="text-xs text-gray-400">Masuk</p>
          <p class="font-medium text-gray-700">{formatDateTime(admission.admission_date)}</p>
        </div>
        <div>
          <p class="text-xs text-gray-400">Jenis Admisi</p>
          <p class="font-medium text-gray-700">{ADMISSION_TYPES[admission.admission_type] || '-'}</p>
        </div>
        <div>
          <p class="text-xs text-gray-400">Kamar</p>
          <p class="font-medium text-gray-700">{room?.name || '-'} ({room?.class || '-'} - Lantai {room?.floor || '-'})</p>
        </div>
        <div>
          <p class="text-xs text-gray-400">Bed</p>
          <p class="font-medium text-gray-700">{bed?.bed_number || '-'}</p>
        </div>
        <div>
          <p class="text-xs text-gray-400">Perkiraan Pulang</p>
          <p class="font-medium text-gray-700">{admission.expected_discharge_date ? formatDate(admission.expected_discharge_date) : '-'}</p>
        </div>
        {#if !isActive}
          <div>
            <p class="text-xs text-gray-400">Pulang</p>
            <p class="font-medium text-gray-700">{admission.discharge_date ? formatDateTime(admission.discharge_date) : '-'}</p>
          </div>
        {/if}
      </div>
    </div>

    <!-- Tabs -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200">
      <div class="flex overflow-x-auto border-b border-gray-200 scrollbar-thin">
        {#each tabs as tab}
          <button
            class="flex items-center gap-2 px-5 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-colors
              {activeTab === tab.id
                ? 'border-emerald-600 text-emerald-700 bg-emerald-50/50'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
            onclick={() => activeTab = tab.id}
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              {#if tab.icon === 'activity'}
                <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
              {:else if tab.icon === 'clipboard'}
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z" />
              {:else if tab.icon === 'document'}
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
              {/if}
            </svg>
            {tab.label}
          </button>
        {/each}
      </div>

      <div class="p-6">
        <!-- TAB: OBSERVASI -->
        {#if activeTab === 'observasi'}
          <div class="space-y-6">
            <div class="bg-gray-50 rounded-xl p-5">
              <h3 class="text-md font-semibold text-gray-900 mb-4">Catat Observasi Baru</h3>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div>
                  <label class="label">Waktu</label>
                  <input type="datetime-local" class="input-field" bind:value={vitalForm.observed_at} />
                </div>
                <div>
                  <label class="label">TD Sistolik (mmHg)</label>
                  <input type="number" class="input-field" placeholder="120" bind:value={vitalForm.blood_pressure_sistolik} />
                </div>
                <div>
                  <label class="label">TD Diastolik (mmHg)</label>
                  <input type="number" class="input-field" placeholder="80" bind:value={vitalForm.blood_pressure_diastolik} />
                </div>
                <div>
                  <label class="label">Suhu (&deg;C)</label>
                  <input type="number" step="0.1" class="input-field" placeholder="36.5" bind:value={vitalForm.temperature} />
                </div>
                <div>
                  <label class="label">Nadi (x/menit)</label>
                  <input type="number" class="input-field" placeholder="80" bind:value={vitalForm.heart_rate} />
                </div>
                <div>
                  <label class="label">RR (x/menit)</label>
                  <input type="number" class="input-field" placeholder="20" bind:value={vitalForm.respiratory_rate} />
                </div>
                <div>
                  <label class="label">SPO2 (%)</label>
                  <input type="number" class="input-field" placeholder="98" bind:value={vitalForm.spo2} />
                </div>
                <div>
                  <label class="label">GCS</label>
                  <input type="number" class="input-field" placeholder="15" bind:value={vitalForm.gcs} />
                </div>
                <div>
                  <label class="label">Berat Badan (kg)</label>
                  <input type="number" step="0.1" class="input-field" placeholder="65" bind:value={vitalForm.weight} />
                </div>
                <div class="col-span-2 md:col-span-3">
                  <label class="label">Catatan</label>
                  <input type="text" class="input-field" placeholder="Catatan observasi (opsional)" bind:value={vitalForm.notes} />
                </div>
              </div>
              <div class="flex justify-end mt-4">
                <button class="btn-primary" onclick={addVital} disabled={saving}>
                  {saving ? 'Menyimpan...' : 'Simpan Observasi'}
                </button>
              </div>
            </div>

            {#if vitals.length > 1}
              <div>
                <h3 class="text-md font-semibold text-gray-900 mb-3">Grafik Tren Tanda Vital</h3>
                <VitalChart observations={vitalsDerived} />
              </div>
            {/if}

            <div>
              <h3 class="text-md font-semibold text-gray-900 mb-3">Riwayat Observasi</h3>
              {#if vitals.length === 0}
                <div class="text-center py-8 text-gray-400 border border-dashed border-gray-200 rounded-lg">
                  <p>Belum ada observasi tanda vital</p>
                </div>
              {:else}
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr>
                        <th class="table-header px-4 py-3 text-left">Waktu</th>
                        <th class="table-header px-4 py-3 text-center">TD</th>
                        <th class="table-header px-4 py-3 text-center">Nadi</th>
                        <th class="table-header px-4 py-3 text-center">Suhu</th>
                        <th class="table-header px-4 py-3 text-center">RR</th>
                        <th class="table-header px-4 py-3 text-center">SPO2</th>
                        <th class="table-header px-4 py-3 text-center">GCS</th>
                        <th class="table-header px-4 py-3 text-center w-16">Aksi</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each vitalsDerived as v}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell font-medium whitespace-nowrap">{formatDateTime(v.observed_at)}</td>
                          <td class="table-cell text-center">{v.blood_pressure_sistolik ? `${v.blood_pressure_sistolik}/${v.blood_pressure_diastolik || '-'}` : '-'}</td>
                          <td class="table-cell text-center">{v.heart_rate ?? '-'}</td>
                          <td class="table-cell text-center">{v.temperature ?? '-'}</td>
                          <td class="table-cell text-center">{v.respiratory_rate ?? '-'}</td>
                          <td class="table-cell text-center">{v.spo2 ?? '-'}</td>
                          <td class="table-cell text-center">{v.gcs ?? '-'}</td>
                          <td class="table-cell text-center">
                            <button class="text-red-500 hover:text-red-700 p-1" onclick={() => deleteVital(v.id)} title="Hapus">
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                              </svg>
                            </button>
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              {/if}
            </div>
          </div>

        <!-- TAB: ASUHAN KEPERAWATAN -->
        {:else if activeTab === 'asuhan'}
          <div class="space-y-6">
            <div class="bg-gray-50 rounded-xl p-5">
              <h3 class="text-md font-semibold text-gray-900 mb-4">Catat Asuhan Keperawatan Harian</h3>
              <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label class="label">Tanggal</label>
                  <input type="date" class="input-field" bind:value={careForm.care_date} />
                </div>
                <div>
                  <label class="label">Shift</label>
                  <select class="select-field" bind:value={careForm.shift}>
                    {#each Object.entries(NURSING_SHIFTS) as [value, label]}
                      <option value={value}>{label}</option>
                    {/each}
                  </select>
                </div>
              </div>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                <div>
                  <label class="label">Data Subjektif (S)</label>
                  <textarea class="input-field" rows="2" placeholder="Keluhan pasien..." bind:value={careForm.subjective}></textarea>
                </div>
                <div>
                  <label class="label">Data Objektif (O)</label>
                  <textarea class="input-field" rows="2" placeholder="Hasil pemeriksaan objektif..." bind:value={careForm.objective}></textarea>
                </div>
                <div>
                  <label class="label">Diagnosa Keperawatan</label>
                  <textarea class="input-field" rows="2" placeholder="Contoh: Nyeri akut b.d ..." bind:value={careForm.nursing_diagnosis}></textarea>
                </div>
                <div>
                  <label class="label">Tujuan (SLKI)</label>
                  <textarea class="input-field" rows="2" placeholder="Tujuan yang diharapkan..." bind:value={careForm.goal}></textarea>
                </div>
                <div>
                  <label class="label">Intervensi (SIKI)</label>
                  <textarea class="input-field" rows="2" placeholder="Rencana intervensi keperawatan..." bind:value={careForm.intervention}></textarea>
                </div>
                <div>
                  <label class="label">Implementasi</label>
                  <textarea class="input-field" rows="2" placeholder="Tindakan yang dilakukan..." bind:value={careForm.implementation}></textarea>
                </div>
                <div class="md:col-span-2">
                  <label class="label">Evaluasi (SOAP)</label>
                  <textarea class="input-field" rows="2" placeholder="Hasil evaluasi..." bind:value={careForm.evaluation}></textarea>
                </div>
              </div>
              <div class="flex justify-end mt-4">
                <button class="btn-primary" onclick={addCarePlan} disabled={saving}>
                  {saving ? 'Menyimpan...' : 'Simpan Asuhan'}
                </button>
              </div>
            </div>

            <div>
              <h3 class="text-md font-semibold text-gray-900 mb-3">Riwayat Asuhan Keperawatan</h3>
              {#if carePlans.length === 0}
                <div class="text-center py-8 text-gray-400 border border-dashed border-gray-200 rounded-lg">
                  <p>Belum ada catatan asuhan keperawatan</p>
                </div>
              {:else}
                <div class="space-y-4">
                  {#each careGroups as [date, entries]}
                    <div>
                      <div class="flex items-center justify-between mb-2">
                        <h4 class="text-sm font-semibold text-gray-700">{formatDate(date)}</h4>
                        <span class="text-xs text-gray-400">{entries.length} catatan</span>
                      </div>
                      <div class="space-y-3">
                        {#each entries as entry}
                          <div class="border border-gray-200 rounded-lg p-4">
                            <div class="flex items-center justify-between mb-3">
                              <span class="badge badge-info">{NURSING_SHIFTS[entry.shift] || entry.shift}</span>
                              <button class="text-red-500 hover:text-red-700 p-1" onclick={() => deleteCarePlan(entry.id)} title="Hapus">
                                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                  <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                                </svg>
                              </button>
                            </div>
                            <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                              {#if entry.subjective}
                                <div><span class="font-semibold text-gray-700">S:</span> <span class="text-gray-600 whitespace-pre-wrap">{entry.subjective}</span></div>
                              {/if}
                              {#if entry.objective}
                                <div><span class="font-semibold text-gray-700">O:</span> <span class="text-gray-600 whitespace-pre-wrap">{entry.objective}</span></div>
                              {/if}
                              {#if entry.nursing_diagnosis}
                                <div><span class="font-semibold text-gray-700">Diagnosa:</span> <span class="text-gray-600 whitespace-pre-wrap">{entry.nursing_diagnosis}</span></div>
                              {/if}
                              {#if entry.goal}
                                <div><span class="font-semibold text-gray-700">Tujuan:</span> <span class="text-gray-600 whitespace-pre-wrap">{entry.goal}</span></div>
                              {/if}
                              {#if entry.intervention}
                                <div><span class="font-semibold text-gray-700">Intervensi:</span> <span class="text-gray-600 whitespace-pre-wrap">{entry.intervention}</span></div>
                              {/if}
                              {#if entry.implementation}
                                <div><span class="font-semibold text-gray-700">Implementasi:</span> <span class="text-gray-600 whitespace-pre-wrap">{entry.implementation}</span></div>
                              {/if}
                              {#if entry.evaluation}
                                <div class="md:col-span-2"><span class="font-semibold text-gray-700">Evaluasi:</span> <span class="text-gray-600 whitespace-pre-wrap">{entry.evaluation}</span></div>
                              {/if}
                            </div>
                          </div>
                        {/each}
                      </div>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>
          </div>

        <!-- TAB: RINGKASAN -->
        {:else if activeTab === 'ringkasan'}
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div>
              <h3 class="text-md font-semibold text-gray-900 mb-3">Informasi Pasien</h3>
              <dl class="grid grid-cols-1 gap-x-6 gap-y-2 text-sm">
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">No RM</dt><dd class="font-medium font-mono">{patient?.no_rm || '-'}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Nama</dt><dd class="font-medium">{patient?.full_name || '-'}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Jenis Kelamin</dt><dd class="font-medium">{patient?.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Usia</dt><dd class="font-medium">{calculateAge(patient?.date_of_birth)}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">NIK</dt><dd class="font-medium font-mono">{patient?.nik || '-'}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">No. HP</dt><dd class="font-medium">{patient?.phone || '-'}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Alamat</dt><dd class="font-medium text-right">{patient?.address || '-'}</dd></div>
              </dl>
            </div>
            <div>
              <h3 class="text-md font-semibold text-gray-900 mb-3">Informasi Rawat Inap</h3>
              <dl class="grid grid-cols-1 gap-x-6 gap-y-2 text-sm">
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Kamar</dt><dd class="font-medium">{room?.name || '-'} ({room?.class || '-'})</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Bed</dt><dd class="font-medium">{bed?.bed_number || '-'}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Tanggal Masuk</dt><dd class="font-medium">{formatDateTime(admission.admission_date)}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Jenis Admisi</dt><dd class="font-medium">{ADMISSION_TYPES[admission.admission_type] || '-'}</dd></div>
                <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Perkiraan Pulang</dt><dd class="font-medium">{admission.expected_discharge_date ? formatDate(admission.expected_discharge_date) : '-'}</dd></div>
                {#if admission.discharge_date}
                  <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Tanggal Pulang</dt><dd class="font-medium">{formatDateTime(admission.discharge_date)}</dd></div>
                {/if}
                {#if admission.discharge_condition}
                  <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Kondisi Pulang</dt><dd class="font-medium">{DISCHARGE_CONDITIONS[admission.discharge_condition] || '-'}</dd></div>
                {/if}
                {#if admission.notes}
                  <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Catatan Admisi</dt><dd class="font-medium text-right whitespace-pre-wrap">{admission.notes}</dd></div>
                {/if}
                {#if admission.discharge_summary}
                  <div class="flex justify-between border-b border-gray-100 py-2"><dt class="text-gray-500">Ringkasan Pulang</dt><dd class="font-medium text-right whitespace-pre-wrap">{admission.discharge_summary}</dd></div>
                {/if}
              </dl>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

{#if showDischargeModal}
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <button class="absolute inset-0 bg-black/50" onclick={() => showDischargeModal = false} aria-label="Tutup"></button>
    <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-lg p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Proses Pulang Pasien</h3>
      <p class="text-sm text-gray-500 mb-4">Pasien: <span class="font-medium text-gray-900">{patient?.full_name}</span> - {room?.name} Bed {bed?.bed_number}</p>
      <div class="space-y-4">
        <div>
          <label class="label">Kondisi Pulang</label>
          <select class="select-field" bind:value={dischargeForm.discharge_condition}>
            {#each Object.entries(DISCHARGE_CONDITIONS) as [value, label]}
              <option value={value}>{label}</option>
            {/each}
          </select>
        </div>
        <div>
          <label class="label">Ringkasan Kepulangan</label>
          <textarea class="input-field" rows="4" placeholder="Ringkasan kondisi akhir, edukasi, dan rencana tindak lanjut..." bind:value={dischargeForm.discharge_summary}></textarea>
        </div>
      </div>
      <div class="flex justify-end gap-3 mt-6">
        <button class="btn-secondary" onclick={() => showDischargeModal = false}>Batal</button>
        <button class="btn-danger" onclick={handleDischarge} disabled={saving}>
          {saving ? 'Memproses...' : 'Konfirmasi Pulang'}
        </button>
      </div>
    </div>
  </div>
{/if}
