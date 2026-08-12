<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase';
  import { formatDate, formatDateTime } from '$lib/utils/helpers';
  import { BED_STATUS, ADMISSION_TYPES, ROOM_CLASSES } from '$lib/utils/constants';

  let rooms = $state([]);
  let beds = $state([]);
  let admissions = $state([]);
  let admissionsHistory = $state([]);
  let loading = $state(true);
  let saving = $state(false);
  let toast = $state({ show: false, message: '', type: 'success' });

  let showRoomModal = $state(false);
  let showBedModal = $state(false);
  let roomForm = $state({ name: '', class: 'Kelas 3', floor: '2', bed_count: 2, notes: '' });
  let bedForm = $state({ room_id: '', bed_number: '', notes: '' });

  let stats = $derived({
    totalBeds: beds.filter(b => b.is_active).length,
    available: beds.filter(b => b.status === 'available' && b.is_active).length,
    occupied: beds.filter(b => b.status === 'occupied' && b.is_active).length,
    maintenance: beds.filter(b => b.status === 'maintenance' && b.is_active).length,
    activeAdmissions: admissions.length
  });

  const bedStyle = (status) => {
    switch (status) {
      case 'available': return 'bg-emerald-50 border-emerald-300 text-emerald-700';
      case 'occupied': return 'bg-red-50 border-red-300 text-red-700';
      case 'reserved': return 'bg-blue-50 border-blue-300 text-blue-700';
      case 'maintenance': return 'bg-amber-50 border-amber-300 text-amber-700';
      default: return 'bg-gray-50 border-gray-300 text-gray-600';
    }
  };

  function showToast(message, type = 'success') {
    toast = { show: true, message, type };
    setTimeout(() => { toast.show = false; }, 3000);
  }

  async function loadData() {
    loading = true;
    try {
      const [roomsRes, bedsRes, admRes, historyRes] = await Promise.all([
        supabase.from('inpatient_rooms').select('*').order('floor').order('name'),
        supabase.from('inpatient_beds').select('*, inpatient_rooms(name)').order('bed_number'),
        supabase
          .from('inpatient_admissions')
          .select('*, patients(*), inpatient_beds(*, inpatient_rooms(*))')
          .eq('status', 'admitted')
          .order('admission_date', { ascending: false }),
        supabase
          .from('inpatient_admissions')
          .select('*, patients(full_name, no_rm), inpatient_beds(bed_number, inpatient_rooms(name))')
          .eq('status', 'discharged')
          .order('discharge_date', { ascending: false })
          .limit(50)
      ]);

      if (roomsRes.error) throw roomsRes.error;
      if (bedsRes.error) throw bedsRes.error;
      if (admRes.error) throw admRes.error;
      if (historyRes.error) throw historyRes.error;

      rooms = roomsRes.data || [];
      beds = bedsRes.data || [];
      admissions = admRes.data || [];
      admissionsHistory = historyRes.data || [];
    } catch (e) {
      console.error('Gagal memuat data rawat inap:', e);
      showToast('Gagal memuat data: ' + e.message, 'error');
    } finally {
      loading = false;
    }
  }

  function bedsOfRoom(roomId) {
    return beds
      .filter(b => b.room_id === roomId && b.is_active)
      .sort((a, b) => a.bed_number.localeCompare(b.bed_number));
  }

  function goToAdmit(bedId = null) {
    goto(bedId ? `/rawat-inap/admit?bed=${bedId}` : '/rawat-inap/admit');
  }

  async function addRoom() {
    if (!roomForm.name.trim()) return;
    saving = true;
    try {
      const { data, error } = await supabase
        .from('inpatient_rooms')
        .insert({ name: roomForm.name.trim(), class: roomForm.class, floor: roomForm.floor, notes: roomForm.notes || null })
        .select()
        .single();
      if (error) throw error;

      const bedCount = Math.max(parseInt(roomForm.bed_count || 1, 10), 1);
      const bedsPayload = [];
      for (let i = 1; i <= bedCount; i++) {
        bedsPayload.push({ room_id: data.room_id, bed_number: String(i).padStart(2, '0') });
      }
      const { error: bedErr } = await supabase.from('inpatient_beds').insert(bedsPayload);
      if (bedErr) throw bedErr;

      showRoomModal = false;
      roomForm = { name: '', class: 'Kelas 3', floor: '2', bed_count: 2, notes: '' };
      showToast('Kamar berhasil ditambahkan');
      await loadData();
    } catch (e) {
      console.error('Gagal tambah kamar:', e);
      showToast('Gagal menambahkan kamar', 'error');
    } finally {
      saving = false;
    }
  }

  async function addBed() {
    if (!bedForm.room_id || !bedForm.bed_number.trim()) return;
    saving = true;
    try {
      const { error } = await supabase
        .from('inpatient_beds')
        .insert({ room_id: bedForm.room_id, bed_number: bedForm.bed_number.trim(), notes: bedForm.notes || null });
      if (error) throw error;

      showBedModal = false;
      bedForm = { room_id: '', bed_number: '', notes: '' };
      showToast('Tempat tidur berhasil ditambahkan');
      await loadData();
    } catch (e) {
      console.error('Gagal tambah bed:', e);
      showToast('Gagal menambahkan tempat tidur', 'error');
    } finally {
      saving = false;
    }
  }

  async function toggleBedStatus(bed) {
    const next = bed.status === 'maintenance' ? 'available' : 'maintenance';
    try {
      const { error } = await supabase
        .from('inpatient_beds')
        .update({ status: next, notes: next === 'maintenance' ? bed.notes || 'Dalam perawatan' : bed.notes })
        .eq('bed_id', bed.bed_id);
      if (error) throw error;
      beds = beds.map(b => b.bed_id === bed.bed_id ? { ...b, status: next } : b);
      showToast(next === 'maintenance' ? 'Bed ditandai dalam perawatan' : 'Bed tersedia kembali');
    } catch (e) {
      console.error('Gagal ubah status bed:', e);
      showToast('Gagal mengubah status bed', 'error');
    }
  }

  onMount(() => {
    loadData();
  });
</script>

<svelte:head>
  <title>Rawat Inap - SMARTHEALTH</title>
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

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Keperawatan & Rawat Inap</h1>
      <p class="text-sm text-gray-500 mt-1">Alokasi bed/kamar, asuhan keperawatan, dan observasi tanda vital</p>
    </div>
    <div class="flex items-center gap-2">
      <button class="btn-secondary" onclick={() => showBedModal = true}>
        <svg class="w-4 h-4 mr-2 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Tambah Bed
      </button>
      <button class="btn-secondary" onclick={() => showRoomModal = true}>
        <svg class="w-4 h-4 mr-2 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Kelola Kamar
      </button>
      <button class="btn-success flex items-center gap-2" onclick={() => goToAdmit()}>
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        Admit Pasien
      </button>
    </div>
  </div>

  <!-- Stats -->
  <div class="grid grid-cols-2 lg:grid-cols-5 gap-4">
    <div class="card flex items-center gap-3">
      <div class="w-11 h-11 rounded-xl bg-gray-100 flex items-center justify-center">
        <svg class="w-6 h-6 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342" />
        </svg>
      </div>
      <div>
        <p class="text-2xl font-bold text-gray-900">{stats.totalBeds}</p>
        <p class="text-xs text-gray-500">Total Bed</p>
      </div>
    </div>
    <div class="card flex items-center gap-3">
      <div class="w-11 h-11 rounded-xl bg-emerald-100 flex items-center justify-center">
        <svg class="w-6 h-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
      </div>
      <div>
        <p class="text-2xl font-bold text-emerald-600">{stats.available}</p>
        <p class="text-xs text-gray-500">Tersedia</p>
      </div>
    </div>
    <div class="card flex items-center gap-3">
      <div class="w-11 h-11 rounded-xl bg-red-100 flex items-center justify-center">
        <svg class="w-6 h-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
          <path stroke-linecap="round" stroke-linejoin="round" d="M18.364 18.364A9 9 0 0 0 5.636 5.636m12.728 12.728A9 9 0 0 1 5.636 5.636m12.728 12.728L5.636 5.636" />
        </svg>
      </div>
      <div>
        <p class="text-2xl font-bold text-red-600">{stats.occupied}</p>
        <p class="text-xs text-gray-500">Terisi</p>
      </div>
    </div>
    <div class="card flex items-center gap-3">
      <div class="w-11 h-11 rounded-xl bg-amber-100 flex items-center justify-center">
        <svg class="w-6 h-6 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
          <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z" />
        </svg>
      </div>
      <div>
        <p class="text-2xl font-bold text-amber-600">{stats.maintenance}</p>
        <p class="text-xs text-gray-500">Perawatan</p>
      </div>
    </div>
    <div class="card flex items-center gap-3">
      <div class="w-11 h-11 rounded-xl bg-blue-100 flex items-center justify-center">
        <svg class="w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.75">
          <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z" />
        </svg>
      </div>
      <div>
        <p class="text-2xl font-bold text-blue-600">{stats.activeAdmissions}</p>
        <p class="text-xs text-gray-500">Pasien Aktif</p>
      </div>
    </div>
  </div>

  {#if loading}
    <div class="flex items-center justify-center h-64">
      <div class="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
    </div>
  {:else}
    <!-- Denah Kamar / Alokasi Bed -->
    <div>
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-900">Denah Kamar & Alokasi Bed</h2>
        <div class="flex items-center gap-4 text-xs text-gray-500">
          <span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded bg-emerald-400"></span> Tersedia</span>
          <span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded bg-red-400"></span> Terisi</span>
          <span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded bg-blue-400"></span> Dipesan</span>
          <span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded bg-amber-400"></span> Perawatan</span>
        </div>
      </div>

      {#if rooms.length === 0}
        <div class="card text-center py-12 text-gray-400">
          <p>Belum ada kamar terdaftar. Tambahkan kamar terlebih dahulu.</p>
          <button class="btn-primary mt-4" onclick={() => showRoomModal = true}>Tambah Kamar</button>
        </div>
      {:else}
        <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {#each rooms.filter(r => r.is_active) as room}
            <div class="card p-4">
              <div class="flex items-start justify-between mb-3">
                <div>
                  <h3 class="font-semibold text-gray-900">{room.name}</h3>
                  <div class="flex items-center gap-2 mt-1">
                    <span class="badge badge-gray">{room.class}</span>
                    <span class="text-xs text-gray-400">Lantai {room.floor}</span>
                  </div>
                </div>
                <div class="text-right">
                  <p class="text-lg font-bold text-gray-900">{bedsOfRoom(room.room_id).filter(b => b.status === 'occupied').length}<span class="text-sm text-gray-400">/{bedsOfRoom(room.room_id).length}</span></p>
                  <p class="text-[10px] text-gray-400">terisi</p>
                </div>
              </div>
              <div class="grid grid-cols-4 gap-2">
                {#each bedsOfRoom(room.room_id) as bed}
                  <div
                    role="button"
                    tabindex="0"
                    class="relative aspect-square rounded-lg border-2 flex flex-col items-center justify-center transition-all hover:scale-[1.03] active:scale-[0.97] cursor-pointer {bedStyle(bed.status)}"
                    onclick={() => {
                      if (bed.status === 'available') goToAdmit(bed.bed_id);
                      else if (bed.status === 'maintenance') toggleBedStatus(bed);
                    }}
                    onkeydown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        if (bed.status === 'available') goToAdmit(bed.bed_id);
                        else if (bed.status === 'maintenance') toggleBedStatus(bed);
                      }
                    }}
                    title="{room.name} - Bed {bed.bed_number}: {BED_STATUS[bed.status]}"
                  >
                    <span class="text-xs font-bold">{bed.bed_number}</span>
                    {#if bed.status === 'maintenance'}
                      <button
                        class="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-white border border-gray-200 shadow-sm flex items-center justify-center text-gray-500 hover:text-amber-600"
                        onclick={(e) => { e.stopPropagation(); toggleBedStatus(bed); }}
                        title="Tandai tersedia"
                      >
                        <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    {/if}
                  </div>
                {/each}
              </div>
              {#if room.notes}
                <p class="text-xs text-gray-400 mt-2">{room.notes}</p>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Pasien Rawat Inap Aktif -->
    <div class="card p-0 overflow-hidden">
      <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
        <div>
          <h2 class="text-lg font-semibold text-gray-900">Pasien Rawat Inap Aktif</h2>
          <p class="text-sm text-gray-500">Pasien yang sedang dirawat</p>
        </div>
      </div>
      {#if admissions.length === 0}
        <div class="text-center py-10 text-gray-400">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
            <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z" />
          </svg>
          <p class="font-medium">Tidak ada pasien rawat inap</p>
          <p class="text-sm mt-1">Klik "Admit Pasien" untuk menerima pasien baru</p>
        </div>
      {:else}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr>
                <th class="table-header px-4 py-3 text-left">No RM</th>
                <th class="table-header px-4 py-3 text-left">Nama Pasien</th>
                <th class="table-header px-4 py-3 text-left">Kamar / Bed</th>
                <th class="table-header px-4 py-3 text-left">Jenis</th>
                <th class="table-header px-4 py-3 text-left">Masuk</th>
                <th class="table-header px-4 py-3 text-center">Aksi</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each admissions as adm}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell font-mono text-xs">{adm.patients?.no_rm || '-'}</td>
                  <td class="table-cell font-medium">{adm.patients?.full_name || '-'}</td>
                  <td class="table-cell">
                    <span class="badge badge-info">{adm.inpatient_beds?.inpatient_rooms?.name || '-'} - Bed {adm.inpatient_beds?.bed_number || '-'}</span>
                  </td>
                  <td class="table-cell text-xs">{ADMISSION_TYPES[adm.admission_type] || adm.admission_type}</td>
                  <td class="table-cell text-xs">{formatDateTime(adm.admission_date)}</td>
                  <td class="table-cell text-center">
                    <a href="/rawat-inap/{adm.admission_id}" class="inline-flex items-center gap-1 text-sm text-primary-600 hover:text-primary-800 font-medium">
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z" />
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
                      </svg>
                      Detail
                    </a>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </div>

    <!-- Riwayat Pulang -->
    <div class="card p-0 overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-100">
        <h2 class="text-lg font-semibold text-gray-900">Riwayat Pulang</h2>
        <p class="text-sm text-gray-500">Pasien rawat inap yang telah selesai dirawat</p>
      </div>
      {#if admissionsHistory.length === 0}
        <div class="text-center py-10 text-gray-400">
          <p>Belum ada riwayat</p>
        </div>
      {:else}
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr>
                <th class="table-header px-4 py-3 text-left">No RM</th>
                <th class="table-header px-4 py-3 text-left">Nama Pasien</th>
                <th class="table-header px-4 py-3 text-left">Kamar / Bed</th>
                <th class="table-header px-4 py-3 text-left">Masuk</th>
                <th class="table-header px-4 py-3 text-left">Pulang</th>
                <th class="table-header px-4 py-3 text-left">Kondisi</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#each admissionsHistory as adm}
                <tr class="hover:bg-gray-50 transition-colors">
                  <td class="table-cell font-mono text-xs">{adm.patients?.no_rm || '-'}</td>
                  <td class="table-cell font-medium">{adm.patients?.full_name || '-'}</td>
                  <td class="table-cell text-xs">{adm.inpatient_beds?.inpatient_rooms?.name || '-'} - Bed {adm.inpatient_beds?.bed_number || '-'}</td>
                  <td class="table-cell text-xs">{formatDate(adm.admission_date)}</td>
                  <td class="table-cell text-xs">{formatDate(adm.discharge_date)}</td>
                  <td class="table-cell">
                    {#if adm.discharge_condition === 'sembuh'}
                      <span class="badge badge-success">Sembuh</span>
                    {:else if adm.discharge_condition === 'rujuk'}
                      <span class="badge badge-info">Rujuk</span>
                    {:else if adm.discharge_condition === 'meninggal'}
                      <span class="badge badge-danger">Meninggal</span>
                    {:else if adm.discharge_condition === 'berobat_jalan'}
                      <span class="badge badge-warning">Berobat Jalan</span>
                    {:else}
                      <span class="badge badge-gray">Lainnya</span>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </div>
  {/if}
</div>

{#if showRoomModal}
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <button class="absolute inset-0 bg-black/50" onclick={() => showRoomModal = false} aria-label="Tutup"></button>
    <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Tambah Kamar</h3>
      <div class="space-y-4">
        <div>
          <label class="label">Nama Kamar</label>
          <input type="text" class="input-field" placeholder="Contoh: Kamar Mawar" bind:value={roomForm.name} />
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="label">Kelas</label>
            <select class="select-field" bind:value={roomForm.class}>
              {#each ROOM_CLASSES as cls}
                <option value={cls}>{cls}</option>
              {/each}
            </select>
          </div>
          <div>
            <label class="label">Lantai</label>
            <input type="text" class="input-field" placeholder="2" bind:value={roomForm.floor} />
          </div>
        </div>
        <div>
          <label class="label">Jumlah Tempat Tidur</label>
          <input type="number" min="1" class="input-field" bind:value={roomForm.bed_count} />
        </div>
        <div>
          <label class="label">Keterangan</label>
          <textarea class="input-field" rows="2" bind:value={roomForm.notes}></textarea>
        </div>
      </div>
      <div class="flex justify-end gap-3 mt-6">
        <button class="btn-secondary" onclick={() => showRoomModal = false}>Batal</button>
        <button class="btn-primary" onclick={addRoom} disabled={saving || !roomForm.name.trim()}>
          {saving ? 'Menyimpan...' : 'Simpan'}
        </button>
      </div>
    </div>
  </div>
{/if}

{#if showBedModal}
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <button class="absolute inset-0 bg-black/50" onclick={() => showBedModal = false} aria-label="Tutup"></button>
    <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">Tambah Tempat Tidur</h3>
      <div class="space-y-4">
        <div>
          <label class="label">Kamar</label>
          <select class="select-field" bind:value={bedForm.room_id}>
            <option value="">- Pilih Kamar -</option>
            {#each rooms.filter(r => r.is_active) as room}
              <option value={room.room_id}>{room.name} ({room.class})</option>
            {/each}
          </select>
        </div>
        <div>
          <label class="label">Nomor Bed</label>
          <input type="text" class="input-field" placeholder="01" bind:value={bedForm.bed_number} />
        </div>
        <div>
          <label class="label">Keterangan</label>
          <input type="text" class="input-field" bind:value={bedForm.notes} />
        </div>
      </div>
      <div class="flex justify-end gap-3 mt-6">
        <button class="btn-secondary" onclick={() => showBedModal = false}>Batal</button>
        <button class="btn-primary" onclick={addBed} disabled={saving || !bedForm.room_id || !bedForm.bed_number.trim()}>
          {saving ? 'Menyimpan...' : 'Simpan'}
        </button>
      </div>
    </div>
  </div>
{/if}
