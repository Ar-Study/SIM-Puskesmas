<script>
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase';
  import { formatDate, calculateAge } from '$lib/utils/helpers';
  import { STATUS_PERIKSA } from '$lib/utils/constants';

  const patientId = $derived(page.params.patientId);

  let patient = $state(null);
  let visits = $state([]);
  let loading = $state(true);
  let expandedVisit = $state(null);

  async function loadData() {
    loading = true;
    try {
      const [patientRes, visitsRes] = await Promise.all([
        supabase.from('patients').select('*').eq('patient_id', patientId).single(),
        supabase
          .from('patient_visitations')
          .select(`
            *,
            clinics (name),
            employees (full_name),
            patient_diagnoses (
              *,
              diagnoses (code, name)
            ),
            prescriptions (
              *,
              prescription_items (
                *,
                drugs (name, generic_name, unit)
              )
            )
          `)
          .eq('patient_id', patientId)
          .order('visit_date', { ascending: false })
      ]);

      if (patientRes.error) throw patientRes.error;
      if (visitsRes.error) throw visitsRes.error;

      patient = patientRes.data;
      visits = visitsRes.data || [];
    } catch (e) {
      console.error('Gagal memuat data:', e);
    } finally {
      loading = false;
    }
  }

  function toggleVisit(visitId) {
    expandedVisit = expandedVisit === visitId ? null : visitId;
  }

  $effect(() => {
    if (patientId) loadData();
  });
</script>

<svelte:head>
  <title>Rekam Medis - {patient?.full_name || 'Pasien'} - SMARTHEALTH</title>
</svelte:head>

{#if loading}
  <div class="flex items-center justify-center h-64">
    <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
  </div>
{:else if !patient}
  <div class="text-center py-12">
    <p class="text-gray-500">Data pasien tidak ditemukan</p>
    <button onclick={() => goto('/rekam-medis')} class="btn-primary mt-4">Kembali</button>
  </div>
{:else}
  <div class="space-y-6">
    <div class="flex items-center gap-4">
      <button onclick={() => goto('/rekam-medis')} class="p-2 rounded-lg hover:bg-gray-100 transition-colors">
        <svg class="w-5 h-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
        </svg>
      </button>
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Rekam Medis Pasien</h1>
        <p class="text-sm text-gray-500 mt-1">Riwayat kunjungan dan perawatan</p>
      </div>
    </div>

    <div class="card">
      <div class="flex items-start gap-4">
        <div class="w-16 h-16 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center text-xl font-bold flex-shrink-0">
          {patient.full_name?.charAt(0) || '?'}
        </div>
        <div class="flex-1">
          <div class="flex items-center gap-3 mb-2">
            <h2 class="text-xl font-bold text-gray-900">{patient.full_name}</h2>
            <span class="badge badge-info">{patient.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</span>
          </div>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-3">
            <div>
              <p class="text-xs text-gray-500">No RM</p>
              <p class="text-sm font-semibold text-gray-900">{patient.no_rm}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">NIK</p>
              <p class="text-sm font-semibold text-gray-900">{patient.nik || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Tanggal Lahir</p>
              <p class="text-sm font-semibold text-gray-900">{formatDate(patient.date_of_birth)} ({calculateAge(patient.date_of_birth)})</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Telepon</p>
              <p class="text-sm font-semibold text-gray-900">{patient.phone || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Golongan Darah</p>
              <p class="text-sm font-semibold text-gray-900">{patient.blood_type || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Agama</p>
              <p class="text-sm font-semibold text-gray-900">{patient.religion || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Pekerjaan</p>
              <p class="text-sm font-semibold text-gray-900">{patient.occupation || '-'}</p>
            </div>
            <div>
              <p class="text-xs text-gray-500">Kontak Darurat</p>
              <p class="text-sm font-semibold text-gray-900">{patient.emergency_contact_name || '-'} {patient.emergency_contact_phone ? `(${patient.emergency_contact_phone})` : ''}</p>
            </div>
          </div>
          {#if patient.address}
            <div class="mt-3">
              <p class="text-xs text-gray-500">Alamat</p>
              <p class="text-sm text-gray-700">{patient.address}{patient.village ? `, ${patient.village}` : ''}{patient.district ? `, ${patient.district}` : ''}{patient.city ? `, ${patient.city}` : ''}{patient.province ? ` - ${patient.province}` : ''}</p>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <div class="card">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Riwayat Kunjungan ({visits.length})</h3>
      {#if visits.length === 0}
        <div class="text-center py-8 text-gray-400">
          <p>Belum ada riwayat kunjungan</p>
        </div>
      {:else}
        <div class="space-y-3">
          {#each visits as visit}
            <div class="border border-gray-200 rounded-xl overflow-hidden">
              <button
                onclick={() => toggleVisit(visit.visit_id)}
                class="w-full flex items-center justify-between p-4 hover:bg-gray-50 transition-colors text-left"
              >
                <div class="flex items-center gap-4">
                  <div class="w-10 h-10 rounded-lg bg-emerald-100 text-emerald-700 flex items-center justify-center text-sm font-bold">
                    {new Date(visit.visit_date).getDate()}
                  </div>
                  <div>
                    <p class="text-sm font-semibold text-gray-900">{formatDate(visit.visit_date)}</p>
                    <p class="text-xs text-gray-500">{visit.clinics?.name || '-'} - {visit.employees?.full_name || '-'}</p>
                  </div>
                </div>
                <div class="flex items-center gap-3">
                  {#if visit.status_periksa === '1'}
                    <span class="badge badge-success">Selesai</span>
                  {:else}
                    <span class="badge badge-warning">Menunggu</span>
                  {/if}
                  <svg class="w-5 h-5 text-gray-400 transition-transform duration-200 {expandedVisit === visit.visit_id ? 'rotate-180' : ''}" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
                  </svg>
                </div>
              </button>

              {#if expandedVisit === visit.visit_id}
                <div class="border-t border-gray-100 p-4 bg-gray-50/50 space-y-4">
                  {#if visit.patient_diagnoses && visit.patient_diagnoses.length > 0}
                    <div>
                      <h4 class="text-sm font-semibold text-gray-700 mb-2">Diagnosa</h4>
                      <div class="flex flex-wrap gap-2">
                        {#each visit.patient_diagnoses as pd}
                          <span class="badge badge-info">
                            {pd.diagnoses?.code} - {pd.diagnoses?.name}
                            <span class="text-xs opacity-60 ml-1">({pd.diagnosis_type})</span>
                          </span>
                        {/each}
                      </div>
                    </div>
                  {/if}

                  {#if visit.prescriptions && visit.prescriptions.length > 0}
                    <div>
                      <h4 class="text-sm font-semibold text-gray-700 mb-2">Resep Obat</h4>
                      {#each visit.prescriptions as prescription}
                        <div class="bg-white rounded-lg border border-gray-200 p-3 mb-2">
                          <div class="flex items-center gap-2 mb-2">
                            <span class="badge {prescription.status === 'dispensed' ? 'badge-success' : 'badge-warning'}">
                              {prescription.status === 'dispensed' ? 'Sudah Diambil' : 'Belum Diambil'}
                            </span>
                            <span class="text-xs text-gray-500">{formatDate(prescription.created_at)}</span>
                          </div>
                          {#if prescription.prescription_items && prescription.prescription_items.length > 0}
                            <div class="space-y-1">
                              {#each prescription.prescription_items as item}
                                <div class="flex items-center justify-between text-sm">
                                  <span class="text-gray-700">{item.drugs?.name || '-'}</span>
                                  <span class="text-gray-500">{item.quantity} {item.drugs?.unit || 'tablet'} - {item.dosage || '-'} - {item.frequency || '-'}</span>
                                </div>
                              {/each}
                            </div>
                          {/if}
                        </div>
                      {/each}
                    </div>
                  {/if}

                  {#if visit.description}
                    <div>
                      <h4 class="text-sm font-semibold text-gray-700 mb-1">Catatan</h4>
                      <p class="text-sm text-gray-600">{visit.description}</p>
                    </div>
                  {/if}
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </div>
{/if}
