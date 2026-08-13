<script>
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import { supabase } from '$lib/supabase';
  import { formatDate, formatDateTime, calculateAge } from '$lib/utils/helpers';
  import { STATUS_PEMBAYARAN, STATUS_PERIKSA, STATUS_KELUAR, VISIT_TYPES } from '$lib/utils/constants';

  let visit = $state(null);
  let patient = $state(null);
  let clinic = $state(null);
  let doctor = $state(null);
  let payor = $state(null);
  let assessment = $state(null);
  let cpptList = $state([]);
  let diagnoses = $state([]);
  let prescriptions = $state([]);
  let loading = $state(true);
  let error = $state('');

  const visitId = $derived(page.params.visitId);

  function appPath(path) {
    return `${base}${path}`;
  }

  async function loadVisitData() {
    loading = true;
    error = '';
    try {
      const { data: visitData, error: visitErr } = await supabase
        .from('patient_visitations')
        .select('*, patients(*), clinics(*), employees!patient_visitations_doctor_id_fkey(full_name, specialization), payors(*)')
        .eq('visit_id', visitId)
        .single();

      if (visitErr) throw visitErr;
      if (!visitData) throw new Error('Data kunjungan tidak ditemukan');

      visit = visitData;
      patient = visitData.patients;
      clinic = visitData.clinics;
      doctor = visitData.employees;
      payor = visitData.payors;

      const [assessmentRes, cpptRes, diagnosisRes, prescriptionRes] = await Promise.all([
        supabase.from('assessments').select('*').eq('visit_id', visitId).order('created_at', { ascending: false }).limit(1).maybeSingle(),
        supabase.from('cppt').select('*').eq('visit_id', visitId).order('created_at', { ascending: false }),
        supabase.from('patient_diagnoses').select('*, diagnoses(*)').eq('visit_id', visitId),
        supabase.from('prescriptions').select('*, prescription_items(*, drugs(*))').eq('visit_id', visitId).order('created_at', { ascending: false })
      ]);

      assessment = assessmentRes.data;
      cpptList = cpptRes.data || [];
      diagnoses = diagnosisRes.data || [];
      prescriptions = prescriptionRes.data || [];
    } catch (e) {
      console.error('Gagal memuat data kunjungan:', e);
      error = e.message || 'Gagal memuat data kunjungan';
    } finally {
      loading = false;
    }
  }

  function getVisitStatusLabel() {
    if (!visit) return '-';
    if (visit.status_keluar === '1') return 'Sudah Keluar';
    if (visit.status_periksa === '1') return 'Sedang Diperiksa';
    return 'Menunggu';
  }

  function getVisitStatusBadge() {
    if (!visit) return 'badge-gray';
    if (visit.status_keluar === '1') return 'badge-info';
    if (visit.status_periksa === '1') return 'badge-success';
    return 'badge-warning';
  }

  onMount(() => {
    if (visitId) loadVisitData();
  });
</script>

<svelte:head>
  <title>Detail Kunjungan - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div class="flex items-center gap-4">
    <a
      href={appPath('/registrasi')}
      class="flex items-center justify-center w-10 h-10 rounded-lg text-gray-500 hover:bg-gray-100 transition-colors"
    >
      <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
      </svg>
    </a>
    <div class="flex-1">
      <h1 class="text-2xl font-bold text-gray-900">Detail Kunjungan</h1>
      <p class="text-sm text-gray-500 mt-1">Informasi kunjungan dan data pasien</p>
    </div>
    <div class="flex items-center gap-2">
      <a
        href={appPath(`/registrasi/${visitId}/edit`)}
        class="btn-secondary flex items-center gap-2"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125" />
        </svg>
        Edit
      </a>
      <a
        href={appPath(`/rawat-jalan/${visitId}`)}
        class="btn-primary flex items-center gap-2"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6Zm0 9.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25Z" />
        </svg>
        Pemeriksaan
      </a>
    </div>
  </div>

  {#if loading}
    <div class="flex items-center justify-center h-64">
      <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
    </div>
  {:else if error}
    <div class="card">
      <div class="text-center py-12">
        <svg class="w-16 h-16 text-red-300 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
        </svg>
        <p class="text-red-500 font-medium">{error}</p>
        <a href={appPath('/registrasi')} class="btn-secondary mt-4 inline-flex items-center gap-2">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
          </svg>
          Kembali
        </a>
      </div>
    </div>
  {:else if visit && patient}
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2 space-y-6">
        <div class="card">
          <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />
            </svg>
            Data Pasien
          </h2>
          <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">No RM</p>
              <p class="text-sm font-medium text-gray-900 font-mono">{patient.no_rm}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Nama Lengkap</p>
              <p class="text-sm font-medium text-gray-900">{patient.full_name}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Jenis Kelamin</p>
              <p class="text-sm font-medium text-gray-900">{patient.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Tanggal Lahir</p>
              <p class="text-sm font-medium text-gray-900">{formatDate(patient.date_of_birth)}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Umur</p>
              <p class="text-sm font-medium text-gray-900">{calculateAge(patient.date_of_birth)}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">NIK</p>
              <p class="text-sm font-medium text-gray-900 font-mono">{patient.nik || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">No. HP</p>
              <p class="text-sm font-medium text-gray-900">{patient.phone || '-'}</p>
            </div>
            <div class="md:col-span-2">
              <p class="text-xs text-gray-500 uppercase tracking-wide">Alamat</p>
              <p class="text-sm font-medium text-gray-900">{patient.address || '-'}</p>
            </div>
          </div>
        </div>

        <div class="card">
          <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
            </svg>
            Data Kunjungan
          </h2>
          <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">No. Antrian</p>
              <p class="text-sm font-bold text-primary-600 font-mono">{visit.queue_number || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Poli</p>
              <p class="text-sm font-medium text-gray-900">
                <span class="badge badge-info">{clinic?.name || '-'}</span>
              </p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Dokter</p>
              <p class="text-sm font-medium text-gray-900">{doctor?.full_name || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Tanggal Kunjungan</p>
              <p class="text-sm font-medium text-gray-900">{formatDateTime(visit.visit_date)}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Penanggung Biaya</p>
              <p class="text-sm font-medium text-gray-900">{payor?.name || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Status</p>
              <p class="text-sm font-medium">
                <span class="badge {getVisitStatusBadge()}">{getVisitStatusLabel()}</span>
              </p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Status Bayar</p>
              <p class="text-sm font-medium">
                {#if visit.status_pembayaran === '1'}
                  <span class="badge badge-success">Sudah Bayar</span>
                {:else if visit.status_pembayaran === '2'}
                  <span class="badge badge-info">Gratis</span>
                {:else}
                  <span class="badge badge-warning">Belum Bayar</span>
                {/if}
              </p>
            </div>
            <div>
              <p class="text-xs text-gray-500 uppercase tracking-wide">Status Periksa</p>
              <p class="text-sm font-medium">
                {#if visit.status_periksa === '1'}
                  <span class="badge badge-success">Sudah Diperiksa</span>
                {:else}
                  <span class="badge badge-warning">Menunggu</span>
                {/if}
              </p>
            </div>
            {#if visit.description}
              <div class="md:col-span-3">
                <p class="text-xs text-gray-500 uppercase tracking-wide">Keterangan</p>
                <p class="text-sm text-gray-700">{visit.description}</p>
              </div>
            {/if}
          </div>
        </div>

        {#if assessment}
          <div class="card">
            <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3" />
              </svg>
              Asesmen
            </h2>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
              {#if assessment.blood_pressure_sistolik}
                <div>
                  <p class="text-xs text-gray-500">Tekanan Darah</p>
                  <p class="text-sm font-medium text-gray-900">{assessment.blood_pressure_sistolik}/{assessment.blood_pressure_diastolik} mmHg</p>
                </div>
              {/if}
              {#if assessment.heart_rate}
                <div>
                  <p class="text-xs text-gray-500">Nadi</p>
                  <p class="text-sm font-medium text-gray-900">{assessment.heart_rate} x/menit</p>
                </div>
              {/if}
              {#if assessment.temperature}
                <div>
                  <p class="text-xs text-gray-500">Suhu</p>
                  <p class="text-sm font-medium text-gray-900">{assessment.temperature}°C</p>
                </div>
              {/if}
              {#if assessment.spo2}
                <div>
                  <p class="text-xs text-gray-500">SpO2</p>
                  <p class="text-sm font-medium text-gray-900">{assessment.spo2}%</p>
                </div>
              {/if}
              {#if assessment.height}
                <div>
                  <p class="text-xs text-gray-500">Tinggi Badan</p>
                  <p class="text-sm font-medium text-gray-900">{assessment.height} cm</p>
                </div>
              {/if}
              {#if assessment.weight}
                <div>
                  <p class="text-xs text-gray-500">Berat Badan</p>
                  <p class="text-sm font-medium text-gray-900">{assessment.weight} kg</p>
                </div>
              {/if}
              {#if assessment.respiratory_rate}
                <div>
                  <p class="text-xs text-gray-500">Frekuensi Napas</p>
                  <p class="text-sm font-medium text-gray-900">{assessment.respiratory_rate} x/menit</p>
                </div>
              {/if}
              {#if assessment.gcs}
                <div>
                  <p class="text-xs text-gray-500">GCS</p>
                  <p class="text-sm font-medium text-gray-900">{assessment.gcs}</p>
                </div>
              {/if}
            </div>
            {#if assessment.subjective}
              <div class="mt-4 pt-4 border-t border-gray-200">
                <p class="text-xs text-gray-500 uppercase tracking-wide mb-1">Subjektif</p>
                <p class="text-sm text-gray-700">{assessment.subjective}</p>
              </div>
            {/if}
            {#if assessment.objective}
              <div class="mt-4 pt-4 border-t border-gray-200">
                <p class="text-xs text-gray-500 uppercase tracking-wide mb-1">Objektif</p>
                <p class="text-sm text-gray-700">{assessment.objective}</p>
              </div>
            {/if}
          </div>
        {/if}

        {#if cpptList.length > 0}
          <div class="card">
            <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
              </svg>
              CPPT
            </h2>
            <div class="space-y-4">
              {#each cpptList as cppt}
                <div class="p-4 bg-gray-50 rounded-lg border border-gray-200">
                  <div class="flex items-center justify-between mb-2">
                    <p class="text-xs text-gray-500">{formatDateTime(cppt.waktu_masuk)}</p>
                  </div>
                  {#if cppt.subyektif}
                    <div class="mb-2">
                      <p class="text-xs font-semibold text-gray-600">Subyektif</p>
                      <p class="text-sm text-gray-700">{cppt.subyektif}</p>
                    </div>
                  {/if}
                  {#if cppt.obyektif}
                    <div class="mb-2">
                      <p class="text-xs font-semibold text-gray-600">Objektif</p>
                      <p class="text-sm text-gray-700">{cppt.obyektif}</p>
                    </div>
                  {/if}
                  {#if cppt.assessment}
                    <div class="mb-2">
                      <p class="text-xs font-semibold text-gray-600">Assessment</p>
                      <p class="text-sm text-gray-700">{cppt.assessment}</p>
                    </div>
                  {/if}
                  {#if cppt.planning}
                    <div>
                      <p class="text-xs font-semibold text-gray-600">Planning</p>
                      <p class="text-sm text-gray-700">{cppt.planning}</p>
                    </div>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        {/if}

        {#if diagnoses.length > 0}
          <div class="card">
            <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 0 0 .75-.75 2.25 2.25 0 0 0-.1-.664m-5.8 0A2.251 2.251 0 0 1 13.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25ZM6.75 12h.008v.008H6.75V12Zm0 3h.008v.008H6.75V15Zm0 3h.008v.008H6.75V18Z" />
              </svg>
              Diagnosa
            </h2>
            <div class="space-y-2">
              {#each diagnoses as dx}
                <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div>
                    <p class="text-sm font-medium text-gray-900 font-mono">{dx.diagnoses?.code}</p>
                    <p class="text-sm text-gray-600">{dx.diagnoses?.name}</p>
                  </div>
                  <span class="badge {dx.diagnosis_type === 'primer' ? 'badge-danger' : 'badge-gray'}">
                    {dx.diagnosis_type === 'primer' ? 'Primer' : 'Sekunder'}
                  </span>
                </div>
              {/each}
            </div>
          </div>
        {/if}

        {#if prescriptions.length > 0}
          <div class="card">
            <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <svg class="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 0 1-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 0 1 4.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0 1 12 15a9.065 9.065 0 0 0-6.23.693L5 14.5m14.8.8 1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0 1 12 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5" />
              </svg>
              Resep Obat
            </h2>
            <div class="space-y-4">
              {#each prescriptions as rx}
                <div class="p-4 bg-gray-50 rounded-lg border border-gray-200">
                  <div class="flex items-center justify-between mb-3">
                    <p class="text-xs text-gray-500">{formatDateTime(rx.created_at)}</p>
                    <span class="badge {rx.status === 'dispensed' ? 'badge-success' : rx.status === 'cancelled' ? 'badge-danger' : 'badge-warning'}">
                      {rx.status === 'dispensed' ? 'Sudah Diserahkan' : rx.status === 'cancelled' ? 'Dibatalkan' : 'Menunggu'}
                    </span>
                  </div>
                  {#if rx.prescription_items && rx.prescription_items.length > 0}
                    <div class="space-y-2">
                      {#each rx.prescription_items as item}
                        <div class="flex items-center justify-between text-sm">
                          <div>
                            <span class="font-medium text-gray-900">{item.drugs?.name || '-'}</span>
                            <span class="text-gray-500 mx-1">-</span>
                            <span class="text-gray-600">{item.quantity} {item.drugs?.unit || 'tablet'}</span>
                          </div>
                          <span class="text-gray-500 text-xs">{item.dosage} {item.frequency}</span>
                        </div>
                      {/each}
                    </div>
                  {:else}
                    <p class="text-sm text-gray-500 italic">Tidak ada item resep</p>
                  {/if}
                  {#if rx.notes}
                    <p class="mt-2 text-xs text-gray-500">Catatan: {rx.notes}</p>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        {/if}
      </div>

      <div class="space-y-6">
        <div class="card">
          <h3 class="text-sm font-semibold text-gray-900 mb-3">Ringkasan</h3>
          <div class="space-y-3">
            <div class="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
              <div class="w-8 h-8 bg-primary-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0" />
                </svg>
              </div>
              <div>
                <p class="text-xs text-gray-500">Pasien</p>
                <p class="text-sm font-medium">{patient.full_name}</p>
              </div>
            </div>
            <div class="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
              <div class="w-8 h-8 bg-emerald-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
                </svg>
              </div>
              <div>
                <p class="text-xs text-gray-500">Poli</p>
                <p class="text-sm font-medium">{clinic?.name || '-'}</p>
              </div>
            </div>
            <div class="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
              <div class="w-8 h-8 bg-amber-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0" />
                </svg>
              </div>
              <div>
                <p class="text-xs text-gray-500">Dokter</p>
                <p class="text-sm font-medium">{doctor?.full_name || '-'}</p>
              </div>
            </div>
            <div class="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
              <div class="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div>
                <p class="text-xs text-gray-500">Antrian</p>
                <p class="text-sm font-bold font-mono text-primary-600">{visit.queue_number || '-'}</p>
              </div>
            </div>
          </div>
        </div>

        <div class="card">
          <h3 class="text-sm font-semibold text-gray-900 mb-3">Aksi Cepat</h3>
          <div class="space-y-2">
            <a
              href={appPath(`/rawat-jalan/${visitId}`)}
              class="flex items-center gap-3 p-3 rounded-lg hover:bg-primary-50 transition-colors group"
            >
              <div class="w-8 h-8 bg-primary-100 rounded-lg flex items-center justify-center group-hover:bg-primary-200 transition-colors">
                <svg class="w-4 h-4 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6Z" />
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">Mulai Pemeriksaan</p>
                <p class="text-xs text-gray-500">Rawat jalan</p>
              </div>
            </a>
            <a
              href={appPath(`/registrasi/${visitId}/edit`)}
              class="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-100 transition-colors group"
            >
              <div class="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center group-hover:bg-gray-200 transition-colors">
                <svg class="w-4 h-4 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125" />
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">Edit Kunjungan</p>
                <p class="text-xs text-gray-500">Ubah data registrasi</p>
              </div>
            </a>
            <a
              href={appPath(`/kasir/${visitId}`)}
              class="flex items-center gap-3 p-3 rounded-lg hover:bg-emerald-50 transition-colors group"
            >
              <div class="w-8 h-8 bg-emerald-100 rounded-lg flex items-center justify-center group-hover:bg-emerald-200 transition-colors">
                <svg class="w-4 h-4 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z" />
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">Kasir / Billing</p>
                <p class="text-xs text-gray-500">Proses pembayaran</p>
              </div>
            </a>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>
