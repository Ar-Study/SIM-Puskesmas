-- Seed Data for SMARTHEALTH (Puskesmas)
-- ============================================

-- Clinics (Poli Puskesmas)
INSERT INTO public.clinics (clinic_id, name, description, queue_prefix, max_queue_daily) VALUES
('POL-UMUM', 'Poli Umum', 'Pelayanan Umum', 'U', 60),
('POL-ANAK', 'Poli Anak', 'Pediatri', 'A', 40),
('POL-KIA', 'Poli KIA', 'Kesehatan Ibu dan Anak', 'K', 40),
('POL-GIGI', 'Poli Gigi', 'Kedokteran Gigi', 'G', 30),
('POL-KULIT', 'Poli Kulit dan Kelamin', 'Dermatologi', 'D', 20),
('POL-THT', 'Poli THT', 'Telinga Hidung Tenggorokan', 'T', 20),
('POL-MATA', 'Poli Mata', 'Oftalmologi', 'M', 20),
('POL-JIWA', 'Poli Kesehatan Jiwa', 'Psikiatri', 'J', 15),
('POL-LANSIA', 'Poli Lansia', 'Pelayanan Lansia', 'L', 25),
('POL-IGD', 'IGD', 'Instalasi Gawat Darurat', 'E', 30),
('POL-LAB', 'Laboratorium', 'Laboratorium Klinik', 'B', 50),
('POL-FAR', 'Farmasi', 'Apotek', 'F', 0),
('POL-KB', 'Pelayanan KB', 'Keluarga Berencana', 'KB', 20),
('POL-IMUN', 'Imunisasi', 'Pelayanan Imunisasi', 'I', 30),
('POL-UJI', 'Laboratorium Sedia Uji', 'Pelayanan Sedia Uji', 'S', 20);

-- Employees (Staf Puskesmas)
INSERT INTO public.employees (employee_id, full_name, role, gender, specialization) VALUES
('DOC-001', 'dr. Ahmad Suharto, Sp.PD', 'dokter', 'L', 'Penyakit Dalam'),
('DOC-002', 'dr. Siti Rahayu, Sp.A', 'dokter', 'P', 'Anak'),
('DOC-003', 'dr. Budi Prasetyo, Sp.B', 'dokter', 'L', 'Bedah Umum'),
('DOC-004', 'dr. Dewi Lestari, Sp.OG', 'dokter', 'P', 'Kandungan'),
('DOC-005', 'dr. Eko Wijaya, Sp.M', 'dokter', 'L', 'Mata'),
('DOC-006', 'dr. Fitri Handayani, Sp.THT', 'dokter', 'P', 'THT-KL'),
('DOC-007', 'dr. Andi Kurniawan, Sp.KJ', 'dokter', 'L', 'Kesehatan Jiwa'),
('DOC-008', 'dr. Maya Sari', 'dokter', 'P', 'Umum'),
('NRS-001', 'Andi Saputra', 'perawat', 'L', 'Perawat'),
('NRS-002', 'Budi Santoso', 'perawat', 'L', 'Perawat'),
('NRS-003', 'Citra Dewi', 'perawat', 'P', 'Perawat'),
('NRS-004', 'Diana Putri', 'perawat', 'P', 'Perawat'),
('LAB-001', 'Danang Prasetyo', 'lab_teknis', 'L', 'Laboratorium'),
('LAB-002', 'Eka Fitriani', 'lab_teknis', 'P', 'Laboratorium'),
('FRM-001', 'Fajar Nugroho', 'apoteker', 'L', 'Farmasi'),
('KSR-001', 'Gita Sari', 'kasir', 'P', 'Kasir'),
('BID-001', 'Hana Permata, S.ST', 'bidan', 'P', 'Bidan');

-- Payors (Penanggung Biaya)
INSERT INTO public.payors (payor_id, name, type, bpjs_code) VALUES
('PAY-BPJS1', 'BPJS Kesehatan Kelas 1', 'bpjs', '1'),
('PAY-BPJS2', 'BPJS Kesehatan Kelas 2', 'bpjs', '2'),
('PAY-BPJS3', 'BPJS Kesehatan Kelas 3', 'bpjs', '3'),
('PAY-PRIBADI', 'Umum / Pribadi', 'personal', NULL),
('PAY-ASURANSI1', 'Asuransi Kesehatan', 'insurance', NULL);

-- Tariffs (Tarif Puskesmas)
INSERT INTO public.tariffs (tariff_id, category, name, price, clinic_id) VALUES
('TRF-KONS-DU', 'Konsultasi', 'Konsultasi Dokter Umum', 25000, 'POL-UMUM'),
('TRF-KONS-SP', 'Konsultasi', 'Konsultasi Dokter Spesialis', 50000, NULL),
('TRF-KONS-GIGI', 'Konsultasi', 'Konsultasi Dokter Gigi', 30000, 'POL-GIGI'),
('TRF-TDK-TAMBAL', 'Tindakan', 'Tambal Gigi', 75000, 'POL-GIGI'),
('TRF-TDK-SCALING', 'Tindakan', 'Scaling Gigi', 100000, 'POL-GIGI'),
('TRF-TDK-EXTRAKSI', 'Tindakan', 'Ekstraksi Gigi', 100000, 'POL-GIGI'),
('TRF-TDK-INJEKSI', 'Tindakan', 'Injeksi/Intravena', 10000, NULL),
('TRF-TDK-NEBUL', 'Tindakan', 'Nebulisasi', 25000, NULL),
('TRF-TDK-INFUS', 'Tindakan', 'Pemasangan Infus', 35000, NULL),
('TRF-TDK-JAHIT', 'Tindakan', 'Penjahitan Luka', 75000, NULL),
('TRF-TDK-IUD', 'Tindakan', 'Pemasangan IUD', 150000, 'POL-KB'),
('TRF-TDK-IMP', 'Tindakan', 'Pemasangan Implant', 200000, 'POL-KB'),
('TRF-LAB-DARAH', 'Laboratorium', 'Pemeriksaan Darah Lengkap', 30000, 'POL-LAB'),
('TRF-LAB-URIN', 'Laboratorium', 'Pemeriksaan Urine Lengkap', 20000, 'POL-LAB'),
('TRF-LAB-GDS', 'Laboratorium', 'Gula Darah Sewaktu', 15000, 'POL-LAB'),
('TRF-LAB-CHO', 'Laboratorium', 'Cholesterol Total', 20000, 'POL-LAB'),
('TRF-LAB-THB', 'Laboratorium', 'Pemeriksaan HB', 10000, 'POL-LAB'),
('TRF-LAB-LIPID', 'Laboratorium', 'Profil Lipid', 35000, 'POL-LAB'),
('TRF-LAB-FUNGI', 'Laboratorium', 'Pemeriksaan Fungsi Hati', 40000, 'POL-LAB'),
('TRF-LAB-RENAL', 'Laboratorium', 'Pemeriksaan Fungsi Ginjal', 40000, 'POL-LAB'),
('TRF-VIS-DOKTER', 'Visite Dokter', 'Visite Dokter', 25000, NULL);

-- Diagnoses (ICD-10 Umum di Puskesmas)
INSERT INTO public.diagnoses (diagnosis_id, code, name, category) VALUES
('DX-A09', 'A09', 'Diare dan gastroenteritis', 'Penyakit Infeksi'),
('DX-J06', 'J06', 'Infeksi saluran pernapasan akut', 'Respirasi'),
('DX-I10', 'I10', 'Hipertensi primer', 'Kardiovaskular'),
('DX-E11', 'E11', 'Diabetes mellitus tipe 2', 'Endokrin'),
('DX-K29', 'K29', 'Gastritis', 'Gastrointestinal'),
('DX-N39', 'N39', 'Infeksi saluran kemih', 'Urologi'),
('DX-M54', 'M54', 'Dorsalgia (nyeri punggung)', 'Muskuloskeletal'),
('DX-J18', 'J18', 'Pneumonia', 'Respirasi'),
('DX-L03', 'L03', 'Selulitis', 'Dermatologi'),
('DX-H65', 'H65', 'Otitis media', 'THT'),
('DX-K80', 'K80', 'Batu kandung empedu', 'Gastrointestinal'),
('DX-E10', 'E10', 'Diabetes mellitus tipe 1', 'Endokrin'),
('DX-I11', 'I11', 'Hipertensi dengan gagal jantung', 'Kardiovaskular'),
('DX-N18', 'N18', 'Gagal ginjal kronis', 'Urologi'),
('DX-J45', 'J45', 'Asma', 'Respirasi'),
('DX-F32', 'F32', 'Episode depresif Mayor', 'Psikiatri'),
('DX-O80', 'O80', 'Pengiriman spontan', 'Obstetri'),
('DX-L40', 'L40', 'Psoriasis', 'Dermatologi'),
('DX-A08', 'A08', 'Infeksi virus usus', 'Penyakit Infeksi'),
('DX-B54', 'B54', 'Malaria', 'Penyakit Infeksi');

-- Drugs (Obat Puskesmas)
INSERT INTO public.drugs (drug_id, name, generic_name, category, unit, buy_price, sell_price, stock, min_stock) VALUES
('DRG-001', 'Paracetamol 500mg', 'Paracetamol', 'Analgesik', 'tablet', 200, 500, 1000, 100),
('DRG-002', 'Amoxicillin 500mg', 'Amoxicillin', 'Antibiotik', 'kaplet', 800, 1500, 500, 50),
('DRG-003', 'Omeprazol 20mg', 'Omeprazol', 'Gastrointestinal', 'kaplet', 500, 1000, 300, 30),
('DRG-004', 'Metformin 500mg', 'Metformin', 'Endokrin', 'tablet', 300, 700, 400, 40),
('DRG-005', 'Amlodipine 5mg', 'Amlodipine', 'Kardiovaskular', 'tablet', 600, 1200, 350, 30),
('DRG-006', 'Cetirizine 10mg', 'Cetirizine', 'Antihistamin', 'tablet', 300, 700, 250, 25),
('DRG-007', 'Salbutamol Nebulizer', 'Salbutamol', 'Respirasi', 'kotak', 15000, 25000, 50, 10),
('DRG-008', 'Ringer Lactat 500ml', 'Ringer Lactat', 'Infus', 'botol', 8000, 15000, 200, 20),
('DRG-009', 'NaCl 0.9% 500ml', 'Natrium Klorida', 'Infus', 'botol', 6000, 12000, 300, 30),
('DRG-010', 'Diclofenac 50mg', 'Diclofenac', 'Analgesik', 'tablet', 250, 600, 400, 40),
('DRG-011', 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'Antibiotik', 'tablet', 1000, 2000, 200, 20),
('DRG-012', 'Vitamin C 1000mg', 'Ascorbic Acid', 'Vitamin', 'tablet', 150, 400, 800, 50),
('DRG-013', 'Vitamin B Complex', 'Vitamin B Kompleks', 'Vitamin', 'tablet', 100, 300, 600, 50),
('DRG-014', 'ORS Sachet', 'Oral Rehydration Salt', 'Lainnya', 'sachet', 300, 800, 1000, 100),
('DRG-015', 'Ibuprofen 400mg', 'Ibuprofen', 'Analgesik', 'tablet', 250, 600, 500, 50),
('DRG-016', 'Ranitidine 150mg', 'Ranitidine', 'Gastrointestinal', 'tablet', 200, 500, 300, 30),
('DRG-017', 'Dexamethasone 0.5mg', 'Dexamethasone', 'Kortikosteroid', 'tablet', 150, 400, 250, 25),
('DRG-018', 'Prednison 5mg', 'Prednison', 'Kortikosteroid', 'tablet', 200, 500, 200, 20),
('DRG-019', 'Antangin JRG', 'Herbal', 'Lainnya', 'sachet', 500, 1000, 500, 50),
('DRG-020', 'Vitamin A 200000 IU', 'Vitamin A', 'Vitamin', 'kapsul', 2000, 5000, 200, 20);

-- Lab Test Catalog
INSERT INTO public.lab_test_catalog (test_name, category, price, normal_value, unit) VALUES
('Darah Lengkap (Hb, Ht, Leukosit, Trombosit)', 'Hematologi', 30000, 'Hb: 12-16 g/dL', 'g/dL'),
('Laju Endap Darah (LED)', 'Hematologi', 15000, '0-20 mm/jam', 'mm/jam'),
('Gula Darah Sewaktu (GDS)', 'Kimia Darah', 15000, '<200 mg/dL', 'mg/dL'),
('Gula Darah Puasa (GDP)', 'Kimia Darah', 20000, '70-110 mg/dL', 'mg/dL'),
('HbA1c', 'Kimia Darah', 75000, '<6.5%', '%'),
('Kolesterol Total', 'Kimia Darah', 20000, '<200 mg/dL', 'mg/dL'),
('Trigliserida', 'Kimia Darah', 25000, '<150 mg/dL', 'mg/dL'),
('HDL Kolesterol', 'Kimia Darah', 25000, '>40 mg/dL', 'mg/dL'),
('LDL Kolesterol', 'Kimia Darah', 30000, '<100 mg/dL', 'mg/dL'),
('SGOT (AST)', 'Kimia Darah', 25000, '5-40 U/L', 'U/L'),
('SGPT (ALT)', 'Kimia Darah', 25000, '5-40 U/L', 'U/L'),
('Ureum', 'Kimia Darah', 25000, '10-50 mg/dL', 'mg/dL'),
('Kreatinin', 'Kimia Darah', 25000, '0.6-1.2 mg/dL', 'mg/dL'),
('Asam Urat', 'Kimia Darah', 25000, '3.5-7.0 mg/dL', 'mg/dL'),
('Bilirubin Total', 'Kimia Darah', 20000, '0.1-1.2 mg/dL', 'mg/dL'),
('Protein Total', 'Kimia Darah', 20000, '6.0-8.0 g/dL', 'g/dL'),
('Albumin', 'Kimia Darah', 25000, '3.5-5.0 g/dL', 'g/dL'),
('Urine Lengkap', 'Urinalisa', 20000, 'Negatif', ''),
('Urine Rutin', 'Urinalisa', 15000, 'Negatif', ''),
('Feses Lengkap', 'Feses', 15000, 'Normal', ''),
('Uji Rapid Malaria', 'Imunologi', 25000, 'Negatif', ''),
('Uji Rapid Typhoid', 'Imunologi', 30000, 'Negatif', ''),
('HbsAg (Hepatitis B)', 'Imunologi', 35000, 'Negatif', ''),
('Anti HCV (Hepatitis C)', 'Imunologi', 50000, 'Negatif', ''),
('VDRL (Sifilis)', 'Imunologi', 25000, 'Negatif', ''),
('HIV Test', 'Imunologi', 30000, 'Negatif', ''),
('Widal', 'Imunologi', 30000, 'Negatif', ''),
('Darah Rutin', 'Hematologi', 20000, 'Normal', '');
