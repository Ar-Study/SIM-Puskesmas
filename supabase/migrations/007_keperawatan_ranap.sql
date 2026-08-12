-- Migration: Modul Keperawatan & Rawat Inap
-- =============================================
-- 1. Master kamar (inpatient_rooms) & tempat tidur (inpatient_beds)
-- 2. Pendaftaran rawat inap / alokasi bed (inpatient_admissions)
-- 3. Asuhan keperawatan harian (nursing_care_plans)
-- 4. Observasi tanda vital berkala (vital_sign_observations)

-- ============================================
-- 1. KAMAR (ROOM)
-- ============================================
CREATE TABLE IF NOT EXISTS public.inpatient_rooms (
  room_id TEXT PRIMARY KEY DEFAULT ('RMR-' || upper(substr(md5(random()::text), 1, 6))),
  name TEXT NOT NULL,
  class TEXT NOT NULL DEFAULT 'Kelas 3' CHECK (class IN ('Kelas 1','Kelas 2','Kelas 3','VIP')),
  floor TEXT DEFAULT '1',
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 2. TEMPAT TIDUR (BED)
-- ============================================
CREATE TABLE IF NOT EXISTS public.inpatient_beds (
  bed_id TEXT PRIMARY KEY DEFAULT ('BED-' || upper(substr(md5(random()::text), 1, 8))),
  room_id TEXT NOT NULL REFERENCES public.inpatient_rooms(room_id) ON DELETE CASCADE,
  bed_number TEXT NOT NULL,
  status TEXT DEFAULT 'available' CHECK (status IN ('available','occupied','reserved','maintenance')),
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (room_id, bed_number)
);

-- ============================================
-- 3. PASIEN RAWAT INAP (ADMISSION)
-- ============================================
CREATE TABLE IF NOT EXISTS public.inpatient_admissions (
  admission_id TEXT PRIMARY KEY DEFAULT ('RIN-' || upper(substr(md5(random()::text), 1, 8))),
  visit_id TEXT REFERENCES public.patient_visitations(visit_id) ON DELETE SET NULL,
  patient_id TEXT NOT NULL REFERENCES public.patients(patient_id),
  bed_id TEXT REFERENCES public.inpatient_beds(bed_id),
  doctor_id TEXT REFERENCES public.employees(employee_id),
  admission_type TEXT DEFAULT 'plan' CHECK (admission_type IN ('plan','emergency','transfer')),
  admission_date TIMESTAMPTZ DEFAULT now(),
  expected_discharge_date TIMESTAMPTZ,
  discharge_date TIMESTAMPTZ,
  status TEXT DEFAULT 'admitted' CHECK (status IN ('admitted','discharged')),
  discharge_condition TEXT CHECK (discharge_condition IN ('sembuh','berobat_jalan','rujuk','meninggal','lainnya')),
  discharge_summary TEXT,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 4. ASUHAN KEPERAWATAN HARIAN
-- ============================================
CREATE TABLE IF NOT EXISTS public.nursing_care_plans (
  id SERIAL PRIMARY KEY,
  admission_id TEXT NOT NULL REFERENCES public.inpatient_admissions(admission_id) ON DELETE CASCADE,
  visit_id TEXT REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  care_date DATE DEFAULT CURRENT_DATE,
  shift TEXT DEFAULT 'pagi' CHECK (shift IN ('pagi','siang','malam')),
  subjective TEXT,
  objective TEXT,
  nursing_diagnosis TEXT,
  goal TEXT,
  intervention TEXT,
  implementation TEXT,
  evaluation TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 5. OBSERVASI TANDA VITAL BERKALA
-- ============================================
CREATE TABLE IF NOT EXISTS public.vital_sign_observations (
  id SERIAL PRIMARY KEY,
  admission_id TEXT NOT NULL REFERENCES public.inpatient_admissions(admission_id) ON DELETE CASCADE,
  visit_id TEXT REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  observed_at TIMESTAMPTZ DEFAULT now(),
  blood_pressure_sistolik INTEGER,
  blood_pressure_diastolik INTEGER,
  heart_rate INTEGER,
  temperature NUMERIC,
  respiratory_rate INTEGER,
  spo2 INTEGER,
  gcs INTEGER,
  weight NUMERIC,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_beds_room ON public.inpatient_beds(room_id);
CREATE INDEX IF NOT EXISTS idx_beds_status ON public.inpatient_beds(status);
CREATE INDEX IF NOT EXISTS idx_admissions_patient ON public.inpatient_admissions(patient_id);
CREATE INDEX IF NOT EXISTS idx_admissions_bed ON public.inpatient_admissions(bed_id);
CREATE INDEX IF NOT EXISTS idx_admissions_status ON public.inpatient_admissions(status);
CREATE INDEX IF NOT EXISTS idx_nursing_admission ON public.nursing_care_plans(admission_id);
CREATE INDEX IF NOT EXISTS idx_nursing_date ON public.nursing_care_plans(care_date);
CREATE INDEX IF NOT EXISTS idx_vitals_admission ON public.vital_sign_observations(admission_id);
CREATE INDEX IF NOT EXISTS idx_vitals_time ON public.vital_sign_observations(observed_at);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE public.inpatient_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inpatient_beds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inpatient_admissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nursing_care_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vital_sign_observations ENABLE ROW LEVEL SECURITY;

-- Kamar: baca untuk semua, ubah hanya admin
CREATE POLICY "rooms_select" ON public.inpatient_rooms FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "rooms_insert" ON public.inpatient_rooms FOR INSERT WITH CHECK (public.get_user_role() IN ('admin'));
CREATE POLICY "rooms_update" ON public.inpatient_rooms FOR UPDATE USING (public.get_user_role() IN ('admin'));
CREATE POLICY "rooms_delete" ON public.inpatient_rooms FOR DELETE USING (public.get_user_role() IN ('admin'));

-- Tempat tidur: baca semua, alokasi/ubah oleh admin, perawat, dokter
CREATE POLICY "beds_select" ON public.inpatient_beds FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "beds_insert" ON public.inpatient_beds FOR INSERT WITH CHECK (public.get_user_role() IN ('admin'));
CREATE POLICY "beds_update" ON public.inpatient_beds FOR UPDATE USING (public.get_user_role() IN ('admin','perawat','dokter','bidan'));
CREATE POLICY "beds_delete" ON public.inpatient_beds FOR DELETE USING (public.get_user_role() IN ('admin'));

-- Rawat inap: baca semua, input oleh petugas terkait
CREATE POLICY "admissions_select" ON public.inpatient_admissions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "admissions_insert" ON public.inpatient_admissions FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','registrasi','perawat','dokter','bidan'));
CREATE POLICY "admissions_update" ON public.inpatient_admissions FOR UPDATE USING (public.get_user_role() IN ('admin','registrasi','perawat','dokter','bidan','kasir'));
CREATE POLICY "admissions_delete" ON public.inpatient_admissions FOR DELETE USING (public.get_user_role() IN ('admin'));

-- Asuhan keperawatan: baca semua, tulis oleh perawat/dokter/bidan/admin
CREATE POLICY "nursing_select" ON public.nursing_care_plans FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "nursing_insert" ON public.nursing_care_plans FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','perawat','dokter','bidan'));
CREATE POLICY "nursing_update" ON public.nursing_care_plans FOR UPDATE USING (public.get_user_role() IN ('admin','perawat','dokter','bidan'));
CREATE POLICY "nursing_delete" ON public.nursing_care_plans FOR DELETE USING (public.get_user_role() IN ('admin'));

-- Observasi tanda vital: baca semua, tulis oleh perawat/dokter/bidan/admin
CREATE POLICY "vitals_select" ON public.vital_sign_observations FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "vitals_insert" ON public.vital_sign_observations FOR INSERT WITH CHECK (public.get_user_role() IN ('admin','perawat','dokter','bidan'));
CREATE POLICY "vitals_update" ON public.vital_sign_observations FOR UPDATE USING (public.get_user_role() IN ('admin','perawat','dokter','bidan'));
CREATE POLICY "vitals_delete" ON public.vital_sign_observations FOR DELETE USING (public.get_user_role() IN ('admin'));

-- ============================================
-- SEED DATA: Kamar & Tempat Tidur
-- ============================================
INSERT INTO public.inpatient_rooms (room_id, name, class, floor) VALUES
('RMR-MELATI1', 'Kamar Melati 1', 'Kelas 1', '2'),
('RMR-MELATI2', 'Kamar Melati 2', 'Kelas 1', '2'),
('RMR-MAWAR', 'Kamar Mawar', 'Kelas 2', '2'),
('RMR-ANGGREK', 'Kamar Anggrek', 'Kelas 2', '2'),
('RMR-BOUGENVIL', 'Kamar Bougenvil', 'Kelas 3', '3'),
('RMR-KENANGA', 'Kamar Kenanga', 'Kelas 3', '3'),
('RMR-LOTUS', 'Kamar Lotus', 'Kelas 3', '3'),
('RMR-TULIP', 'Kamar Tulip', 'VIP', '2')
ON CONFLICT (room_id) DO NOTHING;

INSERT INTO public.inpatient_beds (bed_id, room_id, bed_number) VALUES
('BED-MEL1-01', 'RMR-MELATI1', '01'),
('BED-MEL1-02', 'RMR-MELATI1', '02'),
('BED-MEL2-01', 'RMR-MELATI2', '01'),
('BED-MEL2-02', 'RMR-MELATI2', '02'),
('BED-MAWAR-01', 'RMR-MAWAR', '01'),
('BED-MAWAR-02', 'RMR-MAWAR', '02'),
('BED-MAWAR-03', 'RMR-MAWAR', '03'),
('BED-MAWAR-04', 'RMR-MAWAR', '04'),
('BED-ANGGR-01', 'RMR-ANGGREK', '01'),
('BED-ANGGR-02', 'RMR-ANGGREK', '02'),
('BED-ANGGR-03', 'RMR-ANGGREK', '03'),
('BED-ANGGR-04', 'RMR-ANGGREK', '04'),
('BED-BOUG-01', 'RMR-BOUGENVIL', '01'),
('BED-BOUG-02', 'RMR-BOUGENVIL', '02'),
('BED-BOUG-03', 'RMR-BOUGENVIL', '03'),
('BED-BOUG-04', 'RMR-BOUGENVIL', '04'),
('BED-BOUG-05', 'RMR-BOUGENVIL', '05'),
('BED-BOUG-06', 'RMR-BOUGENVIL', '06'),
('BED-KEN-01', 'RMR-KENANGA', '01'),
('BED-KEN-02', 'RMR-KENANGA', '02'),
('BED-KEN-03', 'RMR-KENANGA', '03'),
('BED-KEN-04', 'RMR-KENANGA', '04'),
('BED-KEN-05', 'RMR-KENANGA', '05'),
('BED-KEN-06', 'RMR-KENANGA', '06'),
('BED-LOTUS-01', 'RMR-LOTUS', '01'),
('BED-LOTUS-02', 'RMR-LOTUS', '02'),
('BED-LOTUS-03', 'RMR-LOTUS', '03'),
('BED-LOTUS-04', 'RMR-LOTUS', '04'),
('BED-LOTUS-05', 'RMR-LOTUS', '05'),
('BED-LOTUS-06', 'RMR-LOTUS', '06'),
('BED-TULIP-01', 'RMR-TULIP', '01'),
('BED-TULIP-02', 'RMR-TULIP', '02')
ON CONFLICT (room_id, bed_number) DO NOTHING;
