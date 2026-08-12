-- Migration: Poli BPJS Fields
-- =============================================
-- Menambahkan kolom kode BPJS ke tabel clinics dan patient_visitations
-- agar data poli BPJS bisa ditampilkan, di-CRUD di master data,
-- dipilih saat registrasi, dan dikirim ke BPJS saat bridging.

-- ============================================
-- Add BPJS poli code columns to clinics
-- ============================================
ALTER TABLE public.clinics
  ADD COLUMN IF NOT EXISTS kd_poli_bpjs VARCHAR(10),
  ADD COLUMN IF NOT EXISTS kode_antrean VARCHAR(5);

CREATE INDEX IF NOT EXISTS idx_clinics_kd_poli_bpjs ON public.clinics(kd_poli_bpjs);

-- ============================================
-- Add BPJS poli code columns to patient_visitations
-- ============================================
ALTER TABLE public.patient_visitations
  ADD COLUMN IF NOT EXISTS kd_poli_bpjs VARCHAR(10),
  ADD COLUMN IF NOT EXISTS kode_antrean VARCHAR(5);

-- ============================================
-- Seed Data: Mapping clinic_id -> kd_poli_bpjs
-- Uses clinic IDs from seed data (POL-UMUM, POL-ANAK, etc.)
-- Fallback: also match P001-style IDs for other environments
-- ============================================

-- Poli Umum / Poli Penyakit Dalam -> INT
UPDATE public.clinics SET kd_poli_bpjs = 'INT', kode_antrean = 'A'
  WHERE clinic_id IN ('POL-UMUM', 'P001');

-- Poli Anak -> ANA
UPDATE public.clinics SET kd_poli_bpjs = 'ANA', kode_antrean = 'B'
  WHERE clinic_id IN ('POL-ANAK', 'P003');

-- Poli KIA / Kebidanan -> OBG
UPDATE public.clinics SET kd_poli_bpjs = 'OBG', kode_antrean = 'C'
  WHERE clinic_id IN ('POL-KIA', 'P004');

-- Poli Bedah -> BED
UPDATE public.clinics SET kd_poli_bpjs = 'BED', kode_antrean = 'D'
  WHERE clinic_id IN ('POL-BEDAH', 'P005');

-- Poli Syaraf -> NEU
UPDATE public.clinics SET kd_poli_bpjs = 'NEU', kode_antrean = 'N'
  WHERE clinic_id IN ('POL-SYARAF', 'P006');

-- Poli Mata -> MAT
UPDATE public.clinics SET kd_poli_bpjs = 'MAT', kode_antrean = 'G'
  WHERE clinic_id IN ('POL-MATA', 'P008');

-- Poli Kulit & Kelamin -> KLT
UPDATE public.clinics SET kd_poli_bpjs = 'KLT', kode_antrean = 'H'
  WHERE clinic_id IN ('POL-KULIT', 'P009');

-- Poli Gigi & Mulut -> GIG
UPDATE public.clinics SET kd_poli_bpjs = 'GIG', kode_antrean = 'J'
  WHERE clinic_id IN ('POL-GIGI', 'P011');

-- Poli Haemodialisa -> HDL
UPDATE public.clinics SET kd_poli_bpjs = 'HDL', kode_antrean = 'K'
  WHERE clinic_id IN ('POL-DIALISA', 'P046');

-- Poli T.H.T -> THT
UPDATE public.clinics SET kd_poli_bpjs = 'THT', kode_antrean = 'I'
  WHERE clinic_id IN ('POL-THT', 'P010');

-- Poli Kesehatan Jiwa -> PSI
UPDATE public.clinics SET kd_poli_bpjs = 'PSI', kode_antrean = 'R'
  WHERE clinic_id IN ('POL-JIWA', 'P007');

-- IGD -> IGD
UPDATE public.clinics SET kd_poli_bpjs = 'IGD', kode_antrean = 'E'
  WHERE clinic_id IN ('POL-IGD', 'P012');

-- Poli Lansia -> UMU
UPDATE public.clinics SET kd_poli_bpjs = 'UMU', kode_antrean = 'F'
  WHERE clinic_id IN ('POL-LANSIA', 'P017');
