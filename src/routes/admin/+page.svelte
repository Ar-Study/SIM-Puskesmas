<script>
  import { supabase } from '$lib/supabase';
  import { formatDate } from '$lib/utils/helpers';
  import { ROLES, DRUG_CATEGORIES, TARIFF_TYPES, LAB_CATEGORIES } from '$lib/utils/constants';

  let activeTab = $state('poli');
  let loading = $state(true);
  let showModal = $state(false);
  let modalMode = $state('add');
  let editItem = $state(null);
  let saving = $state(false);

  let clinics = $state([]);
  let employees = $state([]);
  let patients = $state([]);
  let drugs = $state([]);
  let tariffs = $state([]);
  let diagnoses = $state([]);
  let profiles = $state([]);

  let form = $state({});

  const tabs = [
    { id: 'poli', label: 'Poli' },
    { id: 'dokter', label: 'Dokter/Staff' },
    { id: 'pasien', label: 'Pasien' },
    { id: 'obat', label: 'Obat' },
    { id: 'tarif', label: 'Tarif' },
    { id: 'diagnosis', label: 'Diagnosis' },
    { id: 'user', label: 'User' }
  ];

  async function loadData() {
    loading = true;
    try {
      const [cRes, eRes, pRes, dRes, tRes, dxRes, uRes] = await Promise.all([
        supabase.from('clinics').select('*').order('name'),
        supabase.from('employees').select('*').order('full_name'),
        supabase.from('patients').select('*').order('full_name').limit(100),
        supabase.from('drugs').select('*').order('name'),
        supabase.from('tariffs').select('*, clinics(name)').order('category'),
        supabase.from('diagnoses').select('*').order('code'),
        supabase.from('profiles').select('*').order('full_name')
      ]);

      clinics = cRes.data || [];
      employees = eRes.data || [];
      patients = pRes.data || [];
      drugs = dRes.data || [];
      tariffs = tRes.data || [];
      diagnoses = dxRes.data || [];
      profiles = uRes.data || [];
    } catch (e) {
      console.error('Gagal memuat data:', e);
    } finally {
      loading = false;
    }
  }

  function openAdd() {
    modalMode = 'add';
    editItem = null;
    form = getDefaultForm();
    showModal = true;
  }

  function openEdit(item) {
    modalMode = 'edit';
    editItem = item;
    form = { ...item };
    showModal = true;
  }

  function getDefaultForm() {
    switch (activeTab) {
      case 'poli': return { name: '', description: '', queue_prefix: 'A', max_queue_daily: 50 };
      case 'dokter': return { full_name: '', role: 'dokter', gender: 'L', phone: '', email: '', specialization: '', str_number: '' };
      case 'obat': return { name: '', generic_name: '', category: 'Lainnya', unit: 'tablet', buy_price: 0, sell_price: 0, stock: 0, min_stock: 10, expiry_date: '', manufacturer: '' };
      case 'tarif': return { category: 'Konsultasi', name: '', description: '', price: 0, clinic_id: '' };
      case 'diagnosis': return { code: '', name: '', description: '', category: '' };
      default: return {};
    }
  }

  async function saveItem() {
    saving = true;
    try {
      let result;
      const table = activeTab === 'poli' ? 'clinics' :
        activeTab === 'dokter' ? 'employees' :
        activeTab === 'obat' ? 'drugs' :
        activeTab === 'tarif' ? 'tariffs' :
        activeTab === 'diagnosis' ? 'diagnoses' : null;

      if (!table) return;

      if (modalMode === 'edit') {
        const idField = activeTab === 'poli' ? 'clinic_id' :
          activeTab === 'dokter' ? 'employee_id' :
          activeTab === 'obat' ? 'drug_id' :
          activeTab === 'tarif' ? 'tariff_id' :
          activeTab === 'diagnosis' ? 'diagnosis_id' : 'id';
        result = await supabase.from(table).update(form).eq(idField, editItem[idField]);
      } else {
        result = await supabase.from(table).insert(form);
      }

      if (result.error) throw result.error;
      showModal = false;
      await loadData();
    } catch (e) {
      console.error('Gagal menyimpan:', e);
      alert('Gagal menyimpan: ' + e.message);
    } finally {
      saving = false;
    }
  }

  async function deleteItem(item) {
    if (!confirm('Yakin ingin menghapus?')) return;
    try {
      const table = activeTab === 'poli' ? 'clinics' :
        activeTab === 'dokter' ? 'employees' :
        activeTab === 'obat' ? 'drugs' :
        activeTab === 'tarif' ? 'tariffs' :
        activeTab === 'diagnosis' ? 'diagnoses' : null;
      const idField = activeTab === 'poli' ? 'clinic_id' :
        activeTab === 'dokter' ? 'employee_id' :
        activeTab === 'obat' ? 'drug_id' :
        activeTab === 'tarif' ? 'tariff_id' :
        activeTab === 'diagnosis' ? 'diagnosis_id' : 'id';

      const { error } = await supabase.from(table).delete().eq(idField, item[idField]);
      if (error) throw error;
      await loadData();
    } catch (e) {
      console.error('Gagal menghapus:', e);
      alert('Gagal menghapus');
    }
  }

  $effect(() => {
    loadData();
  });
</script>

<svelte:head>
  <title>Admin - Master Data - SMARTHEALTH</title>
</svelte:head>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Master Data</h1>
    <p class="text-sm text-gray-500 mt-1">Kelola data master sistem</p>
  </div>

  <div class="card">
    <div class="flex gap-2 mb-6 overflow-x-auto pb-2 border-b border-gray-200">
      {#each tabs as tab}
        <button
          onclick={() => activeTab = tab.id}
          class="px-4 py-2 rounded-lg font-medium text-sm whitespace-nowrap transition-colors {activeTab === tab.id ? 'bg-emerald-600 text-white' : 'text-gray-600 hover:bg-gray-100'}"
        >
          {tab.label}
        </button>
      {/each}
    </div>

    {#if loading}
      <div class="flex items-center justify-center h-64">
        <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
      </div>
    {:else}
      <div class="mb-4 flex justify-end">
        {#if activeTab !== 'pasien' && activeTab !== 'user'}
          <button onclick={openAdd} class="btn-primary">+ Tambah Baru</button>
        {/if}
      </div>

      {#if activeTab === 'poli'}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead><tr><th class="table-header px-4 py-3 text-left">Nama Poli</th><th class="table-header px-4 py-3 text-left">Deskripsi</th><th class="table-header px-4 py-3 text-left">Prefix</th><th class="table-header px-4 py-3 text-left">Max/Hari</th><th class="table-header px-4 py-3 text-left">Status</th><th class="table-header px-4 py-3 text-left">Aksi</th></tr></thead>
            <tbody class="divide-y divide-gray-100">
              {#each clinics as c}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell font-medium">{c.name}</td>
                  <td class="table-cell text-gray-500">{c.description || '-'}</td>
                  <td class="table-cell">{c.queue_prefix}</td>
                  <td class="table-cell">{c.max_queue_daily}</td>
                  <td class="table-cell">{c.is_active ? 'Aktif' : 'Nonaktif'}</td>
                  <td class="table-cell flex gap-2">
                    <button onclick={() => openEdit(c)} class="text-sm text-blue-600 hover:text-blue-700">Edit</button>
                    <button onclick={() => deleteItem(c)} class="text-sm text-red-600 hover:text-red-700">Hapus</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

      {:else if activeTab === 'dokter'}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead><tr><th class="table-header px-4 py-3 text-left">ID</th><th class="table-header px-4 py-3 text-left">Nama</th><th class="table-header px-4 py-3 text-left">Role</th><th class="table-header px-4 py-3 text-left">Spesialisasi</th><th class="table-header px-4 py-3 text-left">Telepon</th><th class="table-header px-4 py-3 text-left">Aksi</th></tr></thead>
            <tbody class="divide-y divide-gray-100">
              {#each employees as e}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell font-mono text-xs">{e.employee_id}</td>
                  <td class="table-cell font-medium">{e.full_name}</td>
                  <td class="table-cell"><span class="badge badge-gray">{e.role}</span></td>
                  <td class="table-cell">{e.specialization || '-'}</td>
                  <td class="table-cell">{e.phone || '-'}</td>
                  <td class="table-cell flex gap-2">
                    <button onclick={() => openEdit(e)} class="text-sm text-blue-600 hover:text-blue-700">Edit</button>
                    <button onclick={() => deleteItem(e)} class="text-sm text-red-600 hover:text-red-700">Hapus</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

      {:else if activeTab === 'pasien'}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead><tr><th class="table-header px-4 py-3 text-left">No RM</th><th class="table-header px-4 py-3 text-left">Nama</th><th class="table-header px-4 py-3 text-left">Gender</th><th class="table-header px-4 py-3 text-left">NIK</th><th class="table-header px-4 py-3 text-left">Telepon</th></tr></thead>
            <tbody class="divide-y divide-gray-100">
              {#each patients as p}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell font-mono text-xs">{p.no_rm}</td>
                  <td class="table-cell font-medium">{p.full_name}</td>
                  <td class="table-cell">{p.gender === 'L' ? 'Laki-laki' : 'Perempuan'}</td>
                  <td class="table-cell font-mono text-xs">{p.nik || '-'}</td>
                  <td class="table-cell">{p.phone || '-'}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

      {:else if activeTab === 'obat'}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead><tr><th class="table-header px-4 py-3 text-left">Nama Obat</th><th class="table-header px-4 py-3 text-left">Generik</th><th class="table-header px-4 py-3 text-left">Kategori</th><th class="table-header px-4 py-3 text-left">Stok</th><th class="table-header px-4 py-3 text-left">Harga Jual</th><th class="table-header px-4 py-3 text-left">Aksi</th></tr></thead>
            <tbody class="divide-y divide-gray-100">
              {#each drugs as d}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell font-medium">{d.name}</td>
                  <td class="table-cell text-gray-500">{d.generic_name || '-'}</td>
                  <td class="table-cell"><span class="badge badge-gray">{d.category || '-'}</span></td>
                  <td class="table-cell">{d.stock} {d.unit}</td>
                  <td class="table-cell">Rp {d.sell_price?.toLocaleString('id-ID')}</td>
                  <td class="table-cell flex gap-2">
                    <button onclick={() => openEdit(d)} class="text-sm text-blue-600 hover:text-blue-700">Edit</button>
                    <button onclick={() => deleteItem(d)} class="text-sm text-red-600 hover:text-red-700">Hapus</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

      {:else if activeTab === 'tarif'}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead><tr><th class="table-header px-4 py-3 text-left">Kategori</th><th class="table-header px-4 py-3 text-left">Nama</th><th class="table-header px-4 py-3 text-left">Poli</th><th class="table-header px-4 py-3 text-left">Harga</th><th class="table-header px-4 py-3 text-left">Aksi</th></tr></thead>
            <tbody class="divide-y divide-gray-100">
              {#each tariffs as t}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell"><span class="badge badge-gray">{t.category}</span></td>
                  <td class="table-cell font-medium">{t.name}</td>
                  <td class="table-cell">{t.clinics?.name || '-'}</td>
                  <td class="table-cell">Rp {t.price?.toLocaleString('id-ID')}</td>
                  <td class="table-cell flex gap-2">
                    <button onclick={() => openEdit(t)} class="text-sm text-blue-600 hover:text-blue-700">Edit</button>
                    <button onclick={() => deleteItem(t)} class="text-sm text-red-600 hover:text-red-700">Hapus</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

      {:else if activeTab === 'diagnosis'}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead><tr><th class="table-header px-4 py-3 text-left">Kode</th><th class="table-header px-4 py-3 text-left">Nama</th><th class="table-header px-4 py-3 text-left">Kategori</th><th class="table-header px-4 py-3 text-left">Aksi</th></tr></thead>
            <tbody class="divide-y divide-gray-100">
              {#each diagnoses as d}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell font-mono text-xs">{d.code}</td>
                  <td class="table-cell font-medium">{d.name}</td>
                  <td class="table-cell">{d.category || '-'}</td>
                  <td class="table-cell flex gap-2">
                    <button onclick={() => openEdit(d)} class="text-sm text-blue-600 hover:text-blue-700">Edit</button>
                    <button onclick={() => deleteItem(d)} class="text-sm text-red-600 hover:text-red-700">Hapus</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

      {:else if activeTab === 'user'}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead><tr><th class="table-header px-4 py-3 text-left">Nama</th><th class="table-header px-4 py-3 text-left">Email</th><th class="table-header px-4 py-3 text-left">Role</th><th class="table-header px-4 py-3 text-left">Status</th></tr></thead>
            <tbody class="divide-y divide-gray-100">
              {#each profiles as u}
                <tr class="hover:bg-gray-50">
                  <td class="table-cell font-medium">{u.full_name}</td>
                  <td class="table-cell text-gray-500">{u.email || '-'}</td>
                  <td class="table-cell"><span class="badge badge-info">{u.role}</span></td>
                  <td class="table-cell">{u.is_active ? 'Aktif' : 'Nonaktif'}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    {/if}
  </div>
</div>

{#if showModal}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={() => showModal = false}>
    <div class="bg-white rounded-2xl shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto" onclick={(e) => e.stopPropagation()}>
      <div class="p-6 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-bold text-gray-900">{modalMode === 'add' ? 'Tambah' : 'Edit'} {tabs.find(t => t.id === activeTab)?.label}</h3>
          <button onclick={() => showModal = false} class="p-2 rounded-lg hover:bg-gray-100">
            <svg class="w-5 h-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
          </button>
        </div>
      </div>
      <div class="p-6 space-y-4">
        {#if activeTab === 'poli'}
          <div><label class="label">Nama Poli</label><input type="text" bind:value={form.name} class="input-field" /></div>
          <div><label class="label">Deskripsi</label><input type="text" bind:value={form.description} class="input-field" /></div>
          <div><label class="label">Prefix Antrian</label><input type="text" bind:value={form.queue_prefix} maxlength="2" class="input-field" /></div>
          <div><label class="label">Max/Hari</label><input type="number" bind:value={form.max_queue_daily} class="input-field" /></div>

        {:else if activeTab === 'dokter'}
          <div><label class="label">Nama Lengkap</label><input type="text" bind:value={form.full_name} class="input-field" /></div>
          <div><label class="label">Role</label><select bind:value={form.role} class="select-field">{#each Object.entries(ROLES) as [k, v]}<option value={k}>{v}</option>{/each}</select></div>
          <div><label class="label">Jenis Kelamin</label><select bind:value={form.gender} class="select-field"><option value="L">Laki-laki</option><option value="P">Perempuan</option></select></div>
          <div><label class="label">Telepon</label><input type="text" bind:value={form.phone} class="input-field" /></div>
          <div><label class="label">Email</label><input type="email" bind:value={form.email} class="input-field" /></div>
          <div><label class="label">Spesialisasi</label><input type="text" bind:value={form.specialization} class="input-field" /></div>
          <div><label class="label">No. STR</label><input type="text" bind:value={form.str_number} class="input-field" /></div>

        {:else if activeTab === 'obat'}
          <div><label class="label">Nama Obat</label><input type="text" bind:value={form.name} class="input-field" /></div>
          <div><label class="label">Nama Generik</label><input type="text" bind:value={form.generic_name} class="input-field" /></div>
          <div><label class="label">Kategori</label><select bind:value={form.category} class="select-field">{#each DRUG_CATEGORIES as c}<option value={c}>{c}</option>{/each}</select></div>
          <div><label class="label">Satuan</label><input type="text" bind:value={form.unit} class="input-field" /></div>
          <div class="grid grid-cols-2 gap-4">
            <div><label class="label">Harga Beli</label><input type="number" bind:value={form.buy_price} class="input-field" /></div>
            <div><label class="label">Harga Jual</label><input type="number" bind:value={form.sell_price} class="input-field" /></div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div><label class="label">Stok</label><input type="number" bind:value={form.stock} class="input-field" /></div>
            <div><label class="label">Min. Stok</label><input type="number" bind:value={form.min_stock} class="input-field" /></div>
          </div>
          <div><label class="label">Tanggal Kadaluarsa</label><input type="date" bind:value={form.expiry_date} class="input-field" /></div>
          <div><label class="label">Produsen</label><input type="text" bind:value={form.manufacturer} class="input-field" /></div>

        {:else if activeTab === 'tarif'}
          <div><label class="label">Kategori</label><select bind:value={form.category} class="select-field">{#each TARIFF_TYPES as t}<option value={t}>{t}</option>{/each}</select></div>
          <div><label class="label">Nama Tarif</label><input type="text" bind:value={form.name} class="input-field" /></div>
          <div><label class="label">Deskripsi</label><input type="text" bind:value={form.description} class="input-field" /></div>
          <div><label class="label">Harga</label><input type="number" bind:value={form.price} class="input-field" /></div>
          <div><label class="label">Poli</label><select bind:value={form.clinic_id} class="select-field"><option value="">Umum</option>{#each clinics as c}<option value={c.clinic_id}>{c.name}</option>{/each}</select></div>

        {:else if activeTab === 'diagnosis'}
          <div><label class="label">Kode ICD</label><input type="text" bind:value={form.code} class="input-field" /></div>
          <div><label class="label">Nama Diagnosis</label><input type="text" bind:value={form.name} class="input-field" /></div>
          <div><label class="label">Deskripsi</label><input type="text" bind:value={form.description} class="input-field" /></div>
          <div><label class="label">Kategori</label><input type="text" bind:value={form.category} class="input-field" /></div>
        {/if}
      </div>
      <div class="p-6 border-t border-gray-200 flex justify-end gap-3">
        <button onclick={() => showModal = false} class="btn-secondary">Batal</button>
        <button onclick={saveItem} disabled={saving} class="btn-primary">
          {saving ? 'Menyimpan...' : 'Simpan'}
        </button>
      </div>
    </div>
  </div>
{/if}
