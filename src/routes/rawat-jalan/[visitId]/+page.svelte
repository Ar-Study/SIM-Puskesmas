<script>
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { getCurrentUser, logAudit } from '$lib/auth';
  import { formatDate, formatDateTime, formatCurrency, calculateAge, debounce } from '$lib/utils/helpers';

  let visitId = $derived(page.params.visitId);

  let loading = $state(true);
  let saving = $state(false);
  let activeTab = $state('asesmen');
  let user = $state(null);
  let profile = $state(null);
  let toast = $state({ show: false, message: '', type: 'success' });

  let visit = $state(null);
  let patient = $state(null);
  let clinic = $state(null);

  // Asesmen
  let assessment = $state({
    blood_pressure_sistolik: '',
    blood_pressure_diastolik: '',
    temperature: '',
    heart_rate: '',
    respiratory_rate: '',
    gcs: '',
    height: '',
    weight: '',
    spo2: '',
    subjective: '',
    objective: ''
  });
  let existingAssessmentId = $state(null);

  // CPPT
  let cpptEntries = $state([]);
  let cpptForm = $state({ subyektif: '', obyektif: '', assessment: '', planning: '' });

  // Diagnosis
  let patientDiagnoses = $state([]);
  let diagnosisSearch = $state('');
  let diagnosisResults = $state([]);
  let searchingDiagnosis = $state(false);

  // Lab
  let labOrders = $state([]);
  let labCatalog = $state([]);
  let labSearch = $state('');
  let labSearchResults = $state([]);
  let searchingLab = $state(false);

  // Resep
  let prescriptions = $state([]);
  let drugSearch = $state('');
  let drugResults = $state([]);
  let searchingDrug = $state(false);
  let prescriptionItems = $state([]);
  let currentDrug = $state(null);
  let drugQuantity = $state(1);
  let drugDosage = $state('');
  let drugFrequency = $state('');
  let drugDuration = $state('');

  // Tagihan
   let treatmentBills = $state([]);
  let tariffSearch = $state('');
  let tariffResults = $state([]);
  let searchingTariff = $state(false);
  let billQuantity = $state(1);
  let invoice = $state(null);

  let totalBiaya = $derived(
    treatmentBills.reduce((sum, b) => sum + (b.amount || 0), 0)
  );

  const tabs = [
    { id: 'asesmen', label: 'Asesmen', icon: 'clipboard-check' },
    { id: 'cppt', label: 'CPPT', icon: 'file-text' },
    { id: 'diagnosis', label: 'Diagnosis', icon: 'search' },
    { id: 'lab', label: 'Laboratorium', icon: 'flask' },
    { id: 'resep', label: 'Resep', icon: 'pill' },
    { id: 'tagihan', label: 'Tagihan', icon: 'receipt' }
  ];

  function showToast(message, type = 'success') {
    toast = { show: true, message, type };
    setTimeout(() => { toast.show = false; }, 3000);
  }

  async function loadVisitData() {
    try {
      const { data, error } = await supabase
        .from('patient_visitations')
        .select('*, patients(*), clinics(*)')
        .eq('visit_id', visitId)
        .single();

      if (error) throw error;
      visit = data;
      patient = data.patients;
      clinic = data.clinics;
    } catch (e) {
      console.error('Gagal memuat data kunjungan:', e);
      showToast('Kunjungan tidak ditemukan', 'error');
    }
  }

  async function loadAssessment() {
    try {
      const { data } = await supabase
        .from('assessments')
        .select('*')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (data) {
        existingAssessmentId = data.id;
        assessment = {
          blood_pressure_sistolik: data.blood_pressure_sistolik || '',
          blood_pressure_diastolik: data.blood_pressure_diastolik || '',
          temperature: data.temperature || '',
          heart_rate: data.heart_rate || '',
          respiratory_rate: data.respiratory_rate || '',
          gcs: data.gcs || '',
          height: data.height || '',
          weight: data.weight || '',
          spo2: data.spo2 || '',
          subjective: data.subjective || '',
          objective: data.objective || ''
        };
      }
    } catch (e) {
      console.error('Gagal memuat asesmen:', e);
    }
  }

  async function loadCppt() {
    try {
      const { data } = await supabase
        .from('cppt')
        .select('*')
        .eq('visit_id', visitId)
        .order('waktu_masuk', { ascending: false });

      cpptEntries = data || [];
    } catch (e) {
      console.error('Gagal memuat CPPT:', e);
    }
  }

  async function loadDiagnoses() {
    try {
      const { data } = await supabase
        .from('patient_diagnoses')
        .select('*, diagnoses(*)')
        .eq('visit_id', visitId);

      patientDiagnoses = (data || []).map(d => ({
        ...d,
        diagnosis_detail: d.diagnoses
      }));
    } catch (e) {
      console.error('Gagal memuat diagnosis:', e);
    }
  }

  async function loadLabOrders() {
    try {
      const { data } = await supabase
        .from('lab_orders')
        .select('*')
        .eq('visit_id', visitId)
        .order('order_date', { ascending: false });

      labOrders = data || [];
    } catch (e) {
      console.error('Gagal memuat order lab:', e);
    }
  }

  async function loadLabCatalog() {
    try {
      const { data } = await supabase
        .from('lab_test_catalog')
        .select('*')
        .eq('is_active', true)
        .order('test_name');

      labCatalog = data || [];
    } catch (e) {
      console.error('Gagal memuat katalog lab:', e);
    }
  }

  async function loadPrescriptions() {
    try {
      const { data } = await supabase
        .from('prescriptions')
        .select('*, prescription_items(*, drugs(*))')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: false });

      prescriptions = data || [];
    } catch (e) {
      console.error('Gagal memuat resep:', e);
    }
  }

  async function loadTreatmentBills() {
    try {
      const { data } = await supabase
        .from('treatment_bills')
        .select('*, tariffs(*)')
        .eq('visit_id', visitId)
        .order('created_at', { ascending: false });

      treatmentBills = (data || []).map(b => ({
        ...b,
        tariff_detail: b.tariffs
      }));
    } catch (e) {
      console.error('Gagal memuat tagihan:', e);
    }
  }

  async function loadInvoice() {
    try {
      const { data } = await supabase
        .from('billing_invoices')
        .select('*')
        .eq('visit_id', visitId)
        .maybeSingle();
      invoice = data;
    } catch (e) {
      console.error('Gagal memuat invoice:', e);
    }
  }

  async function createInvoice() {
    saving = true;
    try {
      const totalAmount = totalBiaya;
      const { data, error } = await supabase
        .from('billing_invoices')
        .insert({
          visit_id: visitId,
          total_amount: totalAmount,
          discount: 0,
          net_amount: totalAmount,
          status: 'unpaid'
        })
        .select()
        .single();
      if (error) throw error;
      invoice = data;
      await logAudit('CREATE', 'billing_invoices', data.invoice_id, null, { visit_id: visitId, total_amount: totalAmount });
      showToast('Tagihan berhasil dibuat untuk kasir');
    } catch (e) {
      console.error('Gagal buat tagihan:', e);
      showToast('Gagal membuat tagihan: ' + e.message, 'error');
    } finally {
      saving = false;
    }
  }

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

    await loadVisitData();
    if (!visit) {
      loading = false;
      return;
    }

    await Promise.all([
      loadAssessment(),
      loadCppt(),
      loadDiagnoses(),
      loadLabOrders(),
      loadLabCatalog(),
      loadPrescriptions(),
      loadTreatmentBills(),
      loadInvoice()
    ]);

    loading = false;
  });

  // === ASESMEN ===
  async function saveAssessment() {
    saving = true;
    try {
      const payload = {
        visit_id: visitId,
        blood_pressure_sistolik: assessment.blood_pressure_sistolik ? Number(assessment.blood_pressure_sistolik) : null,
        blood_pressure_diastolik: assessment.blood_pressure_diastolik ? Number(assessment.blood_pressure_diastolik) : null,
        temperature: assessment.temperature ? Number(assessment.temperature) : null,
        heart_rate: assessment.heart_rate ? Number(assessment.heart_rate) : null,
        respiratory_rate: assessment.respiratory_rate ? Number(assessment.respiratory_rate) : null,
        gcs: assessment.gcs ? Number(assessment.gcs) : null,
        height: assessment.height ? Number(assessment.height) : null,
        weight: assessment.weight ? Number(assessment.weight) : null,
        spo2: assessment.spo2 ? Number(assessment.spo2) : null,
        subjective: assessment.subjective,
        objective: assessment.objective,
         created_by: profile?.profilePersisted ? profile?.id : null
      };

      if (existingAssessmentId) {
        const { error } = await supabase
          .from('assessments')
          .update(payload)
          .eq('id', existingAssessmentId);
        if (error) throw error;
      } else {
        const { data, error } = await supabase
          .from('assessments')
          .insert(payload)
          .select()
          .single();
        if (error) throw error;
        existingAssessmentId = data.id;
      }

      await logAudit('UPSERT', 'assessments', existingAssessmentId, null, payload);
      showToast('Asesmen berhasil disimpan');
    } catch (e) {
      console.error('Gagal simpan asesmen:', e);
      showToast('Gagal menyimpan asesmen', 'error');
    } finally {
      saving = false;
    }
  }

  // === CPPT ===
  async function addCpptEntry() {
    if (!cpptForm.subyektif && !cpptForm.obyektif && !cpptForm.assessment && !cpptForm.planning) return;
    saving = true;
    try {
      const payload = {
        visit_id: visitId,
        subyektif: cpptForm.subyektif,
        obyektif: cpptForm.obyektif,
        assessment: cpptForm.assessment,
        planning: cpptForm.planning,
         created_by: profile?.profilePersisted ? profile?.id : null
      };

      const { data, error } = await supabase
        .from('cppt')
        .insert(payload)
        .select()
        .single();
      if (error) throw error;

      cpptEntries = [data, ...cpptEntries];
      cpptForm = { subyektif: '', obyektif: '', assessment: '', planning: '' };
      await logAudit('CREATE', 'cppt', data.id, null, payload);
      showToast('CPPT berhasil ditambahkan');
    } catch (e) {
      console.error('Gagal tambah CPPT:', e);
      showToast('Gagal menambahkan CPPT', 'error');
    } finally {
      saving = false;
    }
  }

  // === DIAGNOSIS ===
  const searchDiagnoses = debounce(async (q) => {
    if (!q || q.length < 2) { diagnosisResults = []; return; }
    searchingDiagnosis = true;
    try {
      const { data } = await supabase
        .from('diagnoses')
        .select('*')
        .eq('is_active', true)
        .or(`code.ilike.%${q}%,name.ilike.%${q}%`)
        .limit(20);
      diagnosisResults = data || [];
    } catch (e) {
      console.error('Gagal cari diagnosis:', e);
    } finally {
      searchingDiagnosis = false;
    }
  }, 400);

  function handleDiagnosisSearch(e) {
    diagnosisSearch = e.target.value;
    searchDiagnoses(diagnosisSearch);
  }

  async function addDiagnosis(dx, type = 'sekunder') {
    try {
      const existing = patientDiagnoses.find(d => d.diagnosis_id === dx.diagnosis_id);
      if (existing) {
        showToast('Diagnosis sudah ada dalam daftar', 'error');
        return;
      }

      const payload = {
        visit_id: visitId,
        diagnosis_id: dx.diagnosis_id,
        diagnosis_type: type
      };

      const { data, error } = await supabase
        .from('patient_diagnoses')
        .insert(payload)
        .select('*, diagnoses(*)')
        .single();
      if (error) throw error;

      patientDiagnoses = [...patientDiagnoses, { ...data, diagnosis_detail: data.diagnoses }];
      await logAudit('CREATE', 'patient_diagnoses', data.id, null, payload);
      showToast('Diagnosis ditambahkan');
    } catch (e) {
      console.error('Gagal tambah diagnosis:', e);
      showToast('Gagal menambahkan diagnosis', 'error');
    }
  }

  async function removeDiagnosis(recordId) {
    try {
      const { error } = await supabase
        .from('patient_diagnoses')
        .delete()
        .eq('id', recordId);
      if (error) throw error;

      patientDiagnoses = patientDiagnoses.filter(d => d.id !== recordId);
      await logAudit('DELETE', 'patient_diagnoses', recordId);
      showToast('Diagnosis dihapus');
    } catch (e) {
      console.error('Gagal hapus diagnosis:', e);
      showToast('Gagal menghapus diagnosis', 'error');
    }
  }

  async function updateDiagnosisType(recordId, newType) {
    try {
      const { error } = await supabase
        .from('patient_diagnoses')
        .update({ diagnosis_type: newType })
        .eq('id', recordId);
      if (error) throw error;

      patientDiagnoses = patientDiagnoses.map(d =>
        d.id === recordId ? { ...d, diagnosis_type: newType } : d
      );
    } catch (e) {
      console.error('Gagal update tipe diagnosis:', e);
    }
  }

  // === LAB ===
  const searchLabTests = debounce(async (q) => {
    if (!q || q.length < 1) { labSearchResults = []; return; }
    searchingLab = true;
    try {
      const { data } = await supabase
        .from('lab_test_catalog')
        .select('*')
        .eq('is_active', true)
        .or(`test_name.ilike.%${q}%,category.ilike.%${q}%`)
        .limit(20);
      labSearchResults = data || [];
    } catch (e) {
      console.error('Gagal cari test lab:', e);
    } finally {
      searchingLab = false;
    }
  }, 400);

  function handleLabSearch(e) {
    labSearch = e.target.value;
    searchLabTests(labSearch);
  }

  async function orderLabTest(test) {
    try {
      const payload = {
        visit_id: visitId,
        catalog_id: test.id,
        test_name: test.test_name,
        category: test.category,
        notes: '',
         created_by: profile?.profilePersisted ? profile?.id : null
      };

      const { data, error } = await supabase
        .from('lab_orders')
        .insert(payload)
        .select()
        .single();
      if (error) throw error;

      labOrders = [data, ...labOrders];
      await logAudit('CREATE', 'lab_orders', data.id, null, payload);
      showToast(`Test "${test.test_name}" dipesan`);
    } catch (e) {
      console.error('Gagal order lab:', e);
      showToast('Gagal memesan test laboratorium', 'error');
    }
  }

  async function cancelLabOrder(orderId) {
    try {
      const { error } = await supabase
        .from('lab_orders')
        .update({ status: 'cancelled' })
        .eq('id', orderId);
      if (error) throw error;

      labOrders = labOrders.map(o => o.id === orderId ? { ...o, status: 'cancelled' } : o);
      showToast('Order lab dibatalkan');
    } catch (e) {
      console.error('Gagal batal order lab:', e);
      showToast('Gagal membatalkan order', 'error');
    }
  }

  // === RESEP ===
  const searchDrugs = debounce(async (q) => {
    if (!q || q.length < 2) { drugResults = []; return; }
    searchingDrug = true;
    try {
      const { data } = await supabase
        .from('drugs')
        .select('*')
        .eq('is_active', true)
        .gt('stock', 0)
        .or(`name.ilike.%${q}%,generic_name.ilike.%${q}%`)
        .limit(20);
      drugResults = data || [];
    } catch (e) {
      console.error('Gagal cari obat:', e);
    } finally {
      searchingDrug = false;
    }
  }, 400);

  function handleDrugSearch(e) {
    drugSearch = e.target.value;
    searchDrugs(drugSearch);
  }

  function selectDrug(drug) {
    currentDrug = drug;
    drugQuantity = 1;
    drugDosage = '';
    drugFrequency = '';
    drugDuration = '';
    drugSearch = '';
    drugResults = [];
  }

  function addPrescriptionItem() {
    if (!currentDrug || !drugQuantity) return;
    prescriptionItems = [...prescriptionItems, {
      drug_id: currentDrug.drug_id,
      name: currentDrug.name,
      unit: currentDrug.unit,
      unit_price: currentDrug.sell_price,
      quantity: drugQuantity,
      dosage: drugDosage,
      frequency: drugFrequency,
      duration: drugDuration,
      total_price: currentDrug.sell_price * drugQuantity
    }];
    currentDrug = null;
  }

  function removePrescriptionItem(index) {
    prescriptionItems = prescriptionItems.filter((_, i) => i !== index);
  }

  async function submitPrescription() {
    if (prescriptionItems.length === 0) return;
    saving = true;
    try {
      const rxPayload = {
        visit_id: visitId,
        prescription_type: 'rajal',
        doctor_id: visit?.doctor_id,
        notes: '',
         created_by: profile?.profilePersisted ? profile?.id : null
      };

      const { data: rxData, error: rxError } = await supabase
        .from('prescriptions')
        .insert(rxPayload)
        .select()
        .single();
      if (rxError) throw rxError;

      const itemsPayload = prescriptionItems.map(item => ({
        prescription_id: rxData.id,
        drug_id: item.drug_id,
        quantity: item.quantity,
        dosage: item.dosage,
        frequency: item.frequency,
        duration: item.duration,
        instruction: `${item.dosage} ${item.frequency} ${item.duration}`.trim(),
        unit_price: item.unit_price,
        total_price: item.total_price
      }));

      const { error: itemsError } = await supabase
        .from('prescription_items')
        .insert(itemsPayload);
      if (itemsError) throw itemsError;

      await logAudit('CREATE', 'prescriptions', rxData.id, null, { ...rxPayload, items: itemsPayload });

      prescriptionItems = [];
      await loadPrescriptions();
      showToast('Resep berhasil dibuat');
    } catch (e) {
      console.error('Gagal buat resep:', e);
      showToast('Gagal membuat resep', 'error');
    } finally {
      saving = false;
    }
  }

  // === TAGIHAN ===
  const searchTariffs = debounce(async (q) => {
    if (!q || q.length < 1) { tariffResults = []; return; }
    searchingTariff = true;
    try {
      const { data } = await supabase
        .from('tariffs')
        .select('*')
        .eq('is_active', true)
        .or(`name.ilike.%${q}%,category.ilike.%${q}%`)
        .limit(20);
      tariffResults = data || [];
    } catch (e) {
      console.error('Gagal cari tarif:', e);
    } finally {
      searchingTariff = false;
    }
  }, 400);

  function handleTariffSearch(e) {
    tariffSearch = e.target.value;
    searchTariffs(tariffSearch);
  }

  async function addBill(tariff) {
    try {
      const qty = billQuantity || 1;
      const amount = tariff.price * qty;

      const payload = {
        visit_id: visitId,
        tariff_id: tariff.tariff_id,
        quantity: qty,
        unit_price: tariff.price,
        amount: amount,
        description: tariff.name,
         created_by: profile?.profilePersisted ? profile?.id : null
      };

      const { data, error } = await supabase
        .from('treatment_bills')
        .insert(payload)
        .select('*, tariffs(*)')
        .single();
      if (error) throw error;

      treatmentBills = [{ ...data, tariff_detail: data.tariffs }, ...treatmentBills];
      billQuantity = 1;
      await logAudit('CREATE', 'treatment_bills', data.id, null, payload);
      showToast(`Tagihan "${tariff.name}" ditambahkan`);
    } catch (e) {
      console.error('Gagal tambah tagihan:', e);
      showToast('Gagal menambahkan tagihan', 'error');
    }
  }

  async function removeBill(recordId) {
    try {
      const { error } = await supabase
        .from('treatment_bills')
        .delete()
        .eq('id', recordId);
      if (error) throw error;

      treatmentBills = treatmentBills.filter(b => b.id !== recordId);
      await logAudit('DELETE', 'treatment_bills', recordId);
      showToast('Tagihan dihapus');
    } catch (e) {
      console.error('Gagal hapus tagihan:', e);
      showToast('Gagal menghapus tagihan', 'error');
    }
  }

  async function markAsExamined() {
    try {
      saving = true;

      const { error: visitErr } = await supabase
        .from('patient_visitations')
        .update({ status_periksa: '1', updated_at: new Date().toISOString() })
        .eq('visit_id', visitId);
      if (visitErr) throw visitErr;

      visit = { ...visit, status_periksa: '1' };

      const totalAmount = totalBiaya;
      const netAmount = totalAmount;

      const { data: existingInvoice } = await supabase
        .from('billing_invoices')
        .select('invoice_id')
        .eq('visit_id', visitId)
        .single();

      if (!existingInvoice) {
        const { data: invData, error: invErr } = await supabase
          .from('billing_invoices')
          .insert({
            visit_id: visitId,
            total_amount: totalAmount,
            discount: 0,
            net_amount: netAmount,
            status: 'unpaid'
          })
          .select()
          .single();
         if (invErr) throw invErr;
         invoice = invData;
         await logAudit('CREATE', 'billing_invoices', invData?.invoice_id, null, { visit_id: visitId, total_amount: totalAmount });
       }

      visit = { ...visit, status_periksa: '1' };
      showToast('Pasien ditandai sudah diperiksa. Tagihan otomatis dibuat untuk kasir.');
    } catch (e) {
      console.error('Gagal update status:', e);
      showToast('Gagal mengubah status: ' + e.message, 'error');
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head>
  <title>Workstation Rawat Jalan - SMARTHEALTH</title>
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
      <p class="text-sm text-gray-500">Memuat workstation...</p>
    </div>
  </div>
{:else if !visit}
  <div class="card text-center py-12">
    <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
    </svg>
    <h3 class="text-lg font-semibold text-gray-700">Kunjungan tidak ditemukan</h3>
    <p class="text-sm text-gray-500 mt-1">Data kunjungan dengan ID <span class="font-mono text-gray-600">{visitId}</span> tidak ditemukan.</p>
    <button class="btn-primary mt-4" onclick={() => goto('/rawat-jalan')}>Kembali ke Rawat Jalan</button>
  </div>
{:else}
  <div class="space-y-4">
    <!-- Header: Patient Info -->
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
              <span class="flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                </svg>
                RM: {patient?.no_rm || '-'}
              </span>
              <span>|</span>
              <span>{patient?.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</span>
              <span>|</span>
              <span>{calculateAge(patient?.date_of_birth)}</span>
              <span>|</span>
              <span class="flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6z" />
                </svg>
                {clinic?.name || '-'}
              </span>
            </div>
          </div>
        </div>
        <div class="flex items-center gap-2">
          {#if visit.status_periksa === '0'}
            <button class="btn-success btn-sm" onclick={markAsExamined}>
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
              </svg>
              Selesai Periksa
            </button>
          {:else if !invoice}
            <button class="btn-primary btn-sm" onclick={createInvoice}>
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9" />
              </svg>
              Buat Tagihan
            </button>
          {:else}
            <span class="badge badge-success">
              <svg class="w-3.5 h-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
              </svg>
              Sudah Diperiksa
            </span>
          {/if}
          <button class="btn-secondary btn-sm" onclick={() => goto('/rawat-jalan')}>
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
            </svg>
            Kembali
          </button>
        </div>
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
            {#if tab.icon === 'clipboard-check'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            {:else if tab.icon === 'file-text'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
              </svg>
            {:else if tab.icon === 'search'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
              </svg>
            {:else if tab.icon === 'flask'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0112 15a9.065 9.065 0 00-6.23.693L5 14.5" />
              </svg>
            {:else if tab.icon === 'pill'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 12c0-1.232-.046-2.453-.138-3.662a4.006 4.006 0 00-3.7-3.7 48.678 48.678 0 00-7.324 0 4.006 4.006 0 00-3.7 3.7c-.017.22-.032.441-.046.662M19.5 12l3-3m-3 3l-3-3m-12 3c0 1.232.046 2.453.138 3.662a4.006 4.006 0 003.7 3.7 48.656 48.656 0 007.324 0 4.006 4.006 0 003.7-3.7c.017-.22.032-.441.046-.662M4.5 12l3 3m-3-3l-3 3" />
              </svg>
            {:else if tab.icon === 'receipt'}
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
              </svg>
            {/if}
            {tab.label}
          </button>
        {/each}
      </div>

      <div class="p-6">
        <!-- TAB: ASESMEN -->
        {#if activeTab === 'asesmen'}
          <div class="space-y-6">
            <div>
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Tanda Vital & Pemeriksaan Fisik</h3>
              <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                <div>
                  <label class="label">Sistolik (mmHg)</label>
                  <input type="number" class="input-field" placeholder="120"
                    bind:value={assessment.blood_pressure_sistolik} />
                </div>
                <div>
                  <label class="label">Diastolik (mmHg)</label>
                  <input type="number" class="input-field" placeholder="80"
                    bind:value={assessment.blood_pressure_diastolik} />
                </div>
                <div>
                  <label class="label">Suhu (&deg;C)</label>
                  <input type="number" step="0.1" class="input-field" placeholder="36.5"
                    bind:value={assessment.temperature} />
                </div>
                <div>
                  <label class="label">Nadi (x/menit)</label>
                  <input type="number" class="input-field" placeholder="80"
                    bind:value={assessment.heart_rate} />
                </div>
                <div>
                  <label class="label">RR (x/menit)</label>
                  <input type="number" class="input-field" placeholder="20"
                    bind:value={assessment.respiratory_rate} />
                </div>
                <div>
                  <label class="label">GCS</label>
                  <input type="number" class="input-field" placeholder="15"
                    bind:value={assessment.gcs} />
                </div>
                <div>
                  <label class="label">TB (cm)</label>
                  <input type="number" step="0.1" class="input-field" placeholder="165"
                    bind:value={assessment.height} />
                </div>
                <div>
                  <label class="label">BB (kg)</label>
                  <input type="number" step="0.1" class="input-field" placeholder="65"
                    bind:value={assessment.weight} />
                </div>
                <div>
                  <label class="label">SPO2 (%)</label>
                  <input type="number" class="input-field" placeholder="98"
                    bind:value={assessment.spo2} />
                </div>
              </div>
            </div>

            <div>
              <label class="label">Subyektif (Keluhan Utama)</label>
              <textarea class="input-field" rows="3"
                placeholder="Tuliskan keluhan utama dan riwayat penyakit sekarang..."
                bind:value={assessment.subjective}></textarea>
            </div>

            <div>
              <label class="label">Objektif (Pemeriksaan Fisik)</label>
              <textarea class="input-field" rows="3"
                placeholder="Tuliskan hasil pemeriksaan fisik..."
                bind:value={assessment.objective}></textarea>
            </div>

            <div class="flex justify-end">
              <button class="btn-primary" onclick={saveAssessment} disabled={saving}>
                {#if saving}
                  <svg class="w-4 h-4 mr-2 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                  </svg>
                  Menyimpan...
                {:else}
                  <svg class="w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                  </svg>
                  Simpan Asesmen
                {/if}
              </button>
            </div>
          </div>

        <!-- TAB: CPPT -->
        {:else if activeTab === 'cppt'}
          <div class="space-y-6">
            <div class="bg-gray-50 rounded-xl p-5">
              <h3 class="text-md font-semibold text-gray-900 mb-4">Tambah CPPT Baru</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="label">Subyektif</label>
                  <textarea class="input-field" rows="3" placeholder="Keluhan pasien..."
                    bind:value={cpptForm.subyektif}></textarea>
                </div>
                <div>
                  <label class="label">Objektif</label>
                  <textarea class="input-field" rows="3" placeholder="Hasil pemeriksaan..."
                    bind:value={cpptForm.obyektif}></textarea>
                </div>
                <div>
                  <label class="label">Assessment</label>
                  <textarea class="input-field" rows="3" placeholder="Diagnosis kerja / analisa..."
                    bind:value={cpptForm.assessment}></textarea>
                </div>
                <div>
                  <label class="label">Planning</label>
                  <textarea class="input-field" rows="3" placeholder="Rencana tindakan / terapi..."
                    bind:value={cpptForm.planning}></textarea>
                </div>
              </div>
              <div class="flex justify-end mt-4">
                <button class="btn-primary" onclick={addCpptEntry} disabled={saving}>
                  {#if saving}
                    Menyimpan...
                  {:else}
                    <svg class="w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                    </svg>
                    Tambah CPPT
                  {/if}
                </button>
              </div>
            </div>

            <div>
              <h3 class="text-md font-semibold text-gray-900 mb-3">Riwayat CPPT</h3>
              {#if cpptEntries.length === 0}
                <div class="text-center py-8 text-gray-400">
                  <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                  </svg>
                  <p>Belum ada catatan CPPT</p>
                </div>
              {:else}
                <div class="space-y-3">
                  {#each cpptEntries as entry}
                    <div class="border border-gray-200 rounded-lg p-4">
                      <div class="flex items-center justify-between mb-3">
                        <span class="text-xs text-gray-500">{formatDateTime(entry.waktu_masuk || entry.created_at)}</span>
                      </div>
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                        {#if entry.subyektif}
                          <div>
                            <span class="font-semibold text-gray-700">Subyektif:</span>
                            <p class="text-gray-600 mt-1 whitespace-pre-wrap">{entry.subyektif}</p>
                          </div>
                        {/if}
                        {#if entry.obyektif}
                          <div>
                            <span class="font-semibold text-gray-700">Objektif:</span>
                            <p class="text-gray-600 mt-1 whitespace-pre-wrap">{entry.obyektif}</p>
                          </div>
                        {/if}
                        {#if entry.assessment}
                          <div>
                            <span class="font-semibold text-gray-700">Assessment:</span>
                            <p class="text-gray-600 mt-1 whitespace-pre-wrap">{entry.assessment}</p>
                          </div>
                        {/if}
                        {#if entry.planning}
                          <div>
                            <span class="font-semibold text-gray-700">Planning:</span>
                            <p class="text-gray-600 mt-1 whitespace-pre-wrap">{entry.planning}</p>
                          </div>
                        {/if}
                      </div>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>
          </div>

        <!-- TAB: DIAGNOSIS -->
        {:else if activeTab === 'diagnosis'}
          <div class="space-y-6">
            <div>
              <label class="label">Cari Diagnosis ICD-10</label>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                </svg>
                <input type="text" class="input-field pl-10" placeholder="Ketik kode atau nama diagnosis..."
                  value={diagnosisSearch} oninput={handleDiagnosisSearch} />
                {#if searchingDiagnosis}
                  <div class="absolute right-3 top-1/2 -translate-y-1/2">
                    <div class="w-4 h-4 border-2 border-gray-300 border-t-emerald-600 rounded-full animate-spin"></div>
                  </div>
                {/if}
              </div>
              {#if diagnosisResults.length > 0}
                <div class="mt-2 border border-gray-200 rounded-lg max-h-60 overflow-y-auto bg-white shadow-sm">
                  {#each diagnosisResults as dx}
                    <button
                      class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-gray-50 border-b border-gray-100 last:border-0"
                      onclick={() => addDiagnosis(dx)}
                    >
                      <div>
                        <span class="text-sm font-mono font-semibold text-primary-700">{dx.code}</span>
                        <span class="text-sm text-gray-700 ml-2">{dx.name}</span>
                        {#if dx.category}
                          <span class="badge badge-gray ml-2 text-[10px]">{dx.category}</span>
                        {/if}
                      </div>
                      <svg class="w-4 h-4 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                      </svg>
                    </button>
                  {/each}
                </div>
              {/if}
            </div>

            <div>
              <h3 class="text-md font-semibold text-gray-900 mb-3">Diagnosis Pasien</h3>
              {#if patientDiagnoses.length === 0}
                <div class="text-center py-8 text-gray-400 border border-dashed border-gray-200 rounded-lg">
                  <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                  </svg>
                  <p>Belum ada diagnosis tercatat</p>
                </div>
              {:else}
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr>
                        <th class="table-header px-4 py-3 text-left">Kode</th>
                        <th class="table-header px-4 py-3 text-left">Nama Diagnosis</th>
                        <th class="table-header px-4 py-3 text-left">Tipe</th>
                        <th class="table-header px-4 py-3 text-center w-24">Aksi</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each patientDiagnoses as pd}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell font-mono font-semibold text-primary-700">{pd.diagnosis_detail?.code || '-'}</td>
                          <td class="table-cell">{pd.diagnosis_detail?.name || '-'}</td>
                          <td class="table-cell">
                            <select
                              class="text-xs px-2 py-1 rounded-lg border border-gray-300 focus:outline-none focus:ring-1 focus:ring-primary-500
                                {pd.diagnosis_type === 'primer' ? 'bg-red-50 text-red-700' : 'bg-blue-50 text-blue-700'}"
                              value={pd.diagnosis_type}
                              onchange={(e) => updateDiagnosisType(pd.id, e.target.value)}
                            >
                              <option value="primer">Primer</option>
                              <option value="sekunder">Sekunder</option>
                            </select>
                          </td>
                          <td class="table-cell text-center">
                            <button
                              class="text-red-500 hover:text-red-700 p-1"
                              onclick={() => removeDiagnosis(pd.id)}
                              title="Hapus"
                            >
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

        <!-- TAB: LABORATORIUM -->
        {:else if activeTab === 'lab'}
          <div class="space-y-6">
            <div>
              <label class="label">Cari Pemeriksaan Laboratorium</label>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                </svg>
                <input type="text" class="input-field pl-10" placeholder="Ketik nama test atau kategori..."
                  value={labSearch} oninput={handleLabSearch} />
              </div>
              {#if labSearchResults.length > 0}
                <div class="mt-2 border border-gray-200 rounded-lg max-h-60 overflow-y-auto bg-white shadow-sm">
                  {#each labSearchResults as test}
                    <button
                      class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-gray-50 border-b border-gray-100 last:border-0"
                      onclick={() => orderLabTest(test)}
                    >
                      <div>
                        <span class="text-sm font-medium text-gray-900">{test.test_name}</span>
                        <span class="text-xs text-gray-500 ml-2">{test.category || '-'}</span>
                        <span class="badge badge-gray ml-2 text-[10px]">{formatCurrency(test.price)}</span>
                      </div>
                      <span class="text-xs text-emerald-600 font-medium">Pesan</span>
                    </button>
                  {/each}
                </div>
              {/if}
            </div>

            <div>
              <h3 class="text-md font-semibold text-gray-900 mb-3">Order Laboratorium</h3>
              {#if labOrders.length === 0}
                <div class="text-center py-8 text-gray-400 border border-dashed border-gray-200 rounded-lg">
                  <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3" />
                  </svg>
                  <p>Belum ada order laboratorium</p>
                </div>
              {:else}
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr>
                        <th class="table-header px-4 py-3 text-left">Nama Test</th>
                        <th class="table-header px-4 py-3 text-left">Kategori</th>
                        <th class="table-header px-4 py-3 text-left">Tanggal</th>
                        <th class="table-header px-4 py-3 text-center">Status</th>
                        <th class="table-header px-4 py-3 text-center w-24">Aksi</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each labOrders as order}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell font-medium">{order.test_name}</td>
                          <td class="table-cell text-gray-500">{order.category || '-'}</td>
                          <td class="table-cell">{formatDateTime(order.order_date)}</td>
                          <td class="table-cell text-center">
                            {#if order.status === 'ordered'}
                              <span class="badge badge-warning">Dipesan</span>
                            {:else if order.status === 'in_progress'}
                              <span class="badge badge-info">Dikerjakan</span>
                            {:else if order.status === 'completed'}
                              <span class="badge badge-success">Selesai</span>
                            {:else}
                              <span class="badge badge-gray">Dibatalkan</span>
                            {/if}
                          </td>
                          <td class="table-cell text-center">
                            {#if order.status === 'ordered'}
                              <button
                                class="text-red-500 hover:text-red-700 p-1"
                                onclick={() => cancelLabOrder(order.id)}
                                title="Batalkan"
                              >
                                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                                </svg>
                              </button>
                            {:else}
                              <span class="text-gray-300">-</span>
                            {/if}
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              {/if}
            </div>
          </div>

        <!-- TAB: RESEP -->
        {:else if activeTab === 'resep'}
          <div class="space-y-6">
            {#if currentDrug}
              <div class="bg-emerald-50 border border-emerald-200 rounded-xl p-4">
                <div class="flex items-center justify-between mb-3">
                  <div>
                    <h4 class="font-semibold text-emerald-900">{currentDrug.name}</h4>
                    <p class="text-sm text-emerald-700">{currentDrug.generic_name || '-'} | {currentDrug.unit} | Stok: {currentDrug.stock}</p>
                    <p class="text-sm font-medium text-emerald-800 mt-1">{formatCurrency(currentDrug.sell_price)}/unit</p>
                  </div>
                  <button class="text-gray-400 hover:text-gray-600" onclick={() => currentDrug = null}>
                    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
                <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
                  <div>
                    <label class="label">Jumlah</label>
                    <input type="number" class="input-field" min="1" max={currentDrug.stock}
                      bind:value={drugQuantity} />
                  </div>
                  <div>
                    <label class="label">Dosis</label>
                    <input type="text" class="input-field" placeholder="500mg"
                      bind:value={drugDosage} />
                  </div>
                  <div>
                    <label class="label">Frekuensi</label>
                    <input type="text" class="input-field" placeholder="3x sehari"
                      bind:value={drugFrequency} />
                  </div>
                  <div>
                    <label class="label">Durasi</label>
                    <input type="text" class="input-field" placeholder="7 hari"
                      bind:value={drugDuration} />
                  </div>
                </div>
                <div class="flex justify-end mt-3">
                  <button class="btn-success btn-sm" onclick={addPrescriptionItem}>
                    <svg class="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                    </svg>
                    Tambah ke Resep
                  </button>
                </div>
              </div>
            {:else}
              <div>
                <label class="label">Cari Obat</label>
                <div class="relative">
                  <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                  </svg>
                  <input type="text" class="input-field pl-10" placeholder="Ketik nama obat atau generic name..."
                    value={drugSearch} oninput={handleDrugSearch} />
                </div>
                {#if drugResults.length > 0}
                  <div class="mt-2 border border-gray-200 rounded-lg max-h-60 overflow-y-auto bg-white shadow-sm">
                    {#each drugResults as drug}
                      <button
                        class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-gray-50 border-b border-gray-100 last:border-0"
                        onclick={() => selectDrug(drug)}
                      >
                        <div>
                          <span class="text-sm font-medium text-gray-900">{drug.name}</span>
                          <span class="text-xs text-gray-500 ml-2">{drug.generic_name || ''}</span>
                          <span class="text-xs text-gray-400 ml-2">| {drug.unit} | Stok: {drug.stock}</span>
                        </div>
                        <span class="text-sm font-medium text-emerald-700">{formatCurrency(drug.sell_price)}</span>
                      </button>
                    {/each}
                  </div>
                {/if}
              </div>
            {/if}

            {#if prescriptionItems.length > 0}
              <div>
                <h3 class="text-md font-semibold text-gray-900 mb-3">Item Resep</h3>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr>
                        <th class="table-header px-4 py-3 text-left">Obat</th>
                        <th class="table-header px-4 py-3 text-center">Jumlah</th>
                        <th class="table-header px-4 py-3 text-left">Dosis</th>
                        <th class="table-header px-4 py-3 text-left">Frekuensi</th>
                        <th class="table-header px-4 py-3 text-left">Durasi</th>
                        <th class="table-header px-4 py-3 text-right">Harga</th>
                        <th class="table-header px-4 py-3 text-center w-16"></th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each prescriptionItems as item, idx}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell font-medium">{item.name} <span class="text-gray-400 text-xs">({item.unit})</span></td>
                          <td class="table-cell text-center">{item.quantity}</td>
                          <td class="table-cell">{item.dosage || '-'}</td>
                          <td class="table-cell">{item.frequency || '-'}</td>
                          <td class="table-cell">{item.duration || '-'}</td>
                          <td class="table-cell text-right font-medium">{formatCurrency(item.total_price)}</td>
                          <td class="table-cell text-center">
                            <button class="text-red-500 hover:text-red-700" onclick={() => removePrescriptionItem(idx)}>
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                              </svg>
                            </button>
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                    <tfoot>
                      <tr class="bg-gray-50">
                        <td colspan="5" class="px-4 py-3 text-sm font-semibold text-gray-700 text-right">Total:</td>
                        <td class="px-4 py-3 text-sm font-bold text-gray-900 text-right">
                          {formatCurrency(prescriptionItems.reduce((s, i) => s + i.total_price, 0))}
                        </td>
                        <td></td>
                      </tr>
                    </tfoot>
                  </table>
                </div>
                <div class="flex justify-end mt-4">
                  <button class="btn-primary" onclick={submitPrescription} disabled={saving}>
                    {#if saving}
                      <svg class="w-4 h-4 mr-2 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                      </svg>
                      Menyimpan...
                    {:else}
                      <svg class="w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                      </svg>
                      Simpan Resep
                    {/if}
                  </button>
                </div>
              </div>
            {/if}

            <div>
              <h3 class="text-md font-semibold text-gray-900 mb-3">Riwayat Resep</h3>
              {#if prescriptions.length === 0}
                <div class="text-center py-8 text-gray-400 border border-dashed border-gray-200 rounded-lg">
                  <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 12c0-1.232-.046-2.453-.138-3.662a4.006 4.006 0 00-3.7-3.7 48.678 48.678 0 00-7.324 0 4.006 4.006 0 00-3.7 3.7c-.017.22-.032.441-.046.662M19.5 12l3-3m-3 3l-3-3m-12 3c0 1.232.046 2.453.138 3.662a4.006 4.006 0 003.7 3.7 48.656 48.656 0 007.324 0 4.006 4.006 0 003.7-3.7c.017-.22.032-.441.046-.662M4.5 12l3 3m-3-3l-3 3" />
                  </svg>
                  <p>Belum ada resep</p>
                </div>
              {:else}
                <div class="space-y-3">
                  {#each prescriptions as rx}
                    <div class="border border-gray-200 rounded-lg p-4">
                      <div class="flex items-center justify-between mb-2">
                        <div class="flex items-center gap-3">
                          <span class="text-sm font-semibold text-gray-900">Resep #{rx.id}</span>
                          {#if rx.status === 'pending'}
                            <span class="badge badge-warning">Menunggu</span>
                          {:else if rx.status === 'dispensed'}
                            <span class="badge badge-success">Diambil</span>
                          {:else}
                            <span class="badge badge-gray">Dibatalkan</span>
                          {/if}
                        </div>
                        <span class="text-xs text-gray-500">{formatDateTime(rx.created_at)}</span>
                      </div>
                      {#if rx.prescription_items && rx.prescription_items.length > 0}
                        <div class="mt-2 space-y-1">
                          {#each rx.prescription_items as item}
                            <div class="flex items-center justify-between text-sm bg-gray-50 rounded px-3 py-2">
                              <span>
                                <span class="font-medium text-gray-800">{item.drugs?.name || item.drug_id}</span>
                                <span class="text-gray-500 ml-1">x{item.quantity}</span>
                                {#if item.dosage || item.frequency || item.duration}
                                  <span class="text-gray-400 ml-2">({item.instruction || `${item.dosage || ''} ${item.frequency || ''} ${item.duration || ''}`.trim()})</span>
                                {/if}
                              </span>
                              <span class="font-medium text-gray-700">{formatCurrency(item.total_price)}</span>
                            </div>
                          {/each}
                        </div>
                      {/if}
                    </div>
                  {/each}
                </div>
              {/if}
            </div>
          </div>

        <!-- TAB: TAGIHAN -->
        {:else if activeTab === 'tagihan'}
          <div class="space-y-6">
            <div>
              <label class="label">Cari Tarif / Tindakan</label>
              <div class="relative">
                <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                </svg>
                <input type="text" class="input-field pl-10" placeholder="Ketik nama tarif atau kategori..."
                  value={tariffSearch} oninput={handleTariffSearch} />
              </div>
              {#if tariffResults.length > 0}
                <div class="mt-2 border border-gray-200 rounded-lg max-h-60 overflow-y-auto bg-white shadow-sm">
                  {#each tariffResults as tariff}
                    <button
                      class="flex items-center justify-between w-full px-4 py-3 text-left hover:bg-gray-50 border-b border-gray-100 last:border-0"
                      onclick={() => addBill(tariff)}
                    >
                      <div>
                        <span class="text-sm font-medium text-gray-900">{tariff.name}</span>
                        <span class="badge badge-gray ml-2 text-[10px]">{tariff.category}</span>
                      </div>
                      <span class="text-sm font-medium text-emerald-700">{formatCurrency(tariff.price)}</span>
                    </button>
                  {/each}
                </div>
              {/if}
            </div>

            <div>
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-md font-semibold text-gray-900">Tagihan Tindakan</h3>
                {#if treatmentBills.length > 0}
                  <div class="bg-emerald-50 border border-emerald-200 rounded-lg px-4 py-2">
                    <span class="text-sm text-emerald-700">Total: </span>
                    <span class="text-lg font-bold text-emerald-800">{formatCurrency(totalBiaya)}</span>
                  </div>
                {/if}
              </div>

              {#if treatmentBills.length === 0}
                <div class="text-center py-8 text-gray-400 border border-dashed border-gray-200 rounded-lg">
                  <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                  </svg>
                  <p>Belum ada tagihan</p>
                </div>
              {:else}
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr>
                        <th class="table-header px-4 py-3 text-left">Deskripsi</th>
                        <th class="table-header px-4 py-3 text-left">Kategori</th>
                        <th class="table-header px-4 py-3 text-center">Qty</th>
                        <th class="table-header px-4 py-3 text-right">Harga Satuan</th>
                        <th class="table-header px-4 py-3 text-right">Total</th>
                        <th class="table-header px-4 py-3 text-center w-16"></th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                      {#each treatmentBills as bill}
                        <tr class="hover:bg-gray-50">
                          <td class="table-cell font-medium">{bill.description || bill.tariff_detail?.name || '-'}</td>
                          <td class="table-cell text-gray-500">{bill.tariff_detail?.category || '-'}</td>
                          <td class="table-cell text-center">{bill.quantity}</td>
                          <td class="table-cell text-right">{formatCurrency(bill.unit_price)}</td>
                          <td class="table-cell text-right font-semibold">{formatCurrency(bill.amount)}</td>
                          <td class="table-cell text-center">
                            <button
                              class="text-red-500 hover:text-red-700 p-1"
                              onclick={() => removeBill(bill.id)}
                              title="Hapus"
                            >
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                              </svg>
                            </button>
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                    <tfoot>
                      <tr class="bg-emerald-50 border-t-2 border-emerald-200">
                        <td colspan="4" class="px-4 py-3 text-sm font-bold text-emerald-800 text-right">Total Tagihan:</td>
                        <td class="px-4 py-3 text-lg font-bold text-emerald-900 text-right">{formatCurrency(totalBiaya)}</td>
                        <td></td>
                      </tr>
                    </tfoot>
                  </table>
                </div>
              {/if}
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
