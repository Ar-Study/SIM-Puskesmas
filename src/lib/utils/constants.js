export const ROLES = {
  admin: 'Administrator',
  registrasi: 'Registrasi',
  dokter: 'Dokter',
  perawat: 'Perawat',
  apoteker: 'Apoteker',
  lab_teknis: 'Lab Teknis',
  kasir: 'Kasir',
  bidan: 'Bidan'
};

export const VISIT_TYPES = {
  rawat_jalan: 'Rawat Jalan',
  rawat_inap: 'Rawat Inap',
  igd: 'IGD/Rawat Darurat'
};

export const STATUS_PEMBAYARAN = {
  '0': 'Belum Bayar',
  '1': 'Sudah Bayar',
  '2': 'Gratis'
};

export const STATUS_PERIKSA = {
  '0': 'Belum Diperiksa',
  '1': 'Sudah Diperiksa'
};

export const STATUS_KELUAR = {
  '0': 'Masih di Puskesmas',
  '1': 'Sudah Keluar'
};

export const STATUS_ANTRIAN = {
  waiting: 'Menunggu',
  called: 'Dipanggil',
  in_progress: 'Sedang Diperiksa',
  completed: 'Selesai',
  cancelled: 'Batal'
};

export const DRUG_CATEGORIES = [
  'Antibiotik', 'Analgesik', 'Antipiretik', 'Antihistamin',
  'Antasida', 'Vitamin', 'Suplemen', 'Dermatologi',
  'Kardiovaskular', 'Respirasi', 'Endokrin', 'Neurologi',
  'Gastrointestinal', 'Oftalmologi', 'THT', 'Kontrasepsi', 'Lainnya'
];

export const TARIFF_TYPES = [
  'Konsultasi', 'Tindakan', 'Laboratorium', 'Obat',
  'BMHP', 'Akomodasi', 'Visite Dokter', 'Lainnya'
];

export const PAYOR_TYPES = {
  bpjs: 'BPJS',
  insurance: 'Asuransi',
  personal: 'Pribadi',
  corporate: 'Perusahaan'
};

export const LAB_CATEGORIES = [
  'Hematologi', 'Kimia Darah', 'Imunologi', 'Urinalisa',
  'Feses', 'Mikrobiologi', 'Lainnya'
];

export const DISCHARGE_CONDITIONS = {
  sembuh: 'Sembuh',
  berobat_jalan: 'Berobat Jalan',
  rujuk: 'Rujuk',
  meninggal: 'Meninggal',
  lainnya: 'Lainnya'
};

export const REPORT_TYPES = {
  kunjungan: 'Laporan Kunjungan Pasien',
  sensus_harian: 'Sensus Harian Rawat Jalan',
  penyakit_top10: '10 Besar Penyakit',
  lb1: 'LB 1 - Registrasi dan Perawatan Pasien',
  lb4: 'LB 4 - Pelayanan Rawat Jalan',
  lab_harian: 'Sensus Harian Laboratorium',
  tindakan: 'Rekapitulasi Tindakan',
  pendapatan: 'Pendapatan Kasir'
};
