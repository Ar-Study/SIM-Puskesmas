-- SMARTHEALTH Database Schema for Supabase (PostgreSQL)
-- Sistem Informasi Manajemen Puskesmas
-- ================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. PROFILES (extends Supabase Auth)
-- ============================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  role TEXT NOT NULL CHECK (role IN ('admin','registrasi','dokter','perawat','apoteker','lab_teknis','kasir','bidan')),
  employee_id TEXT,
  is_active BOOLEAN DEFAULT true,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 2. MASTER DATA
-- ============================================
CREATE TABLE public.employees (
  employee_id TEXT PRIMARY KEY DEFAULT ('EMP-' || upper(substr(md5(random()::text), 1, 6))),
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'dokter',
  gender TEXT CHECK (gender IN ('L','P')),
  phone TEXT,
  email TEXT,
  specialization TEXT,
  str_number TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.clinics (
  clinic_id TEXT PRIMARY KEY DEFAULT ('POL-' || upper(substr(md5(random()::text), 1, 6))),
  name TEXT NOT NULL,
  description TEXT,
  queue_prefix TEXT DEFAULT 'A',
  max_queue_daily INTEGER DEFAULT 50,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.payors (
  payor_id TEXT PRIMARY KEY DEFAULT ('PAY-' || upper(substr(md5(random()::text), 1, 6))),
  name TEXT NOT NULL,
  type TEXT CHECK (type IN ('bpjs','insurance','personal','corporate')),
  bpjs_code TEXT,
  contact_person TEXT,
  phone TEXT,
  address TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.diagnoses (
  diagnosis_id TEXT PRIMARY KEY DEFAULT ('DX-' || upper(substr(md5(random()::text), 1, 6))),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.tariffs (
  tariff_id TEXT PRIMARY KEY DEFAULT ('TRF-' || upper(substr(md5(random()::text), 1, 6))),
  category TEXT NOT NULL DEFAULT 'Konsultasi',
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC DEFAULT 0,
  clinic_id TEXT REFERENCES public.clinics(clinic_id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.drugs (
  drug_id TEXT PRIMARY KEY DEFAULT ('DRG-' || upper(substr(md5(random()::text), 1, 6))),
  name TEXT NOT NULL,
  generic_name TEXT,
  category TEXT,
  unit TEXT NOT NULL DEFAULT 'tablet',
  buy_price NUMERIC DEFAULT 0,
  sell_price NUMERIC DEFAULT 0,
  stock INTEGER DEFAULT 0,
  min_stock INTEGER DEFAULT 10,
  expiry_date DATE,
  manufacturer TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.lab_test_catalog (
  id SERIAL PRIMARY KEY,
  test_name TEXT NOT NULL,
  category TEXT,
  price NUMERIC DEFAULT 0,
  normal_value TEXT,
  unit TEXT,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 3. PATIENTS & REGISTRATION
-- ============================================
CREATE TABLE public.patients (
  patient_id TEXT PRIMARY KEY DEFAULT ('PAS-' || upper(substr(md5(random()::text), 1, 8))),
  no_rm TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  gender TEXT NOT NULL CHECK (gender IN ('L','P')),
  date_of_birth DATE NOT NULL,
  nik TEXT,
  phone TEXT,
  address TEXT,
  rt TEXT,
  rw TEXT,
  village TEXT,
  district TEXT,
  city TEXT,
  province TEXT,
  blood_type TEXT,
  religion TEXT,
  marital_status TEXT,
  occupation TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  insurance_number TEXT,
  payor_id TEXT REFERENCES public.payors(payor_id),
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.patient_visitations (
  visit_id TEXT PRIMARY KEY DEFAULT ('VST-' || upper(substr(md5(random()::text), 1, 8))),
  patient_id TEXT NOT NULL REFERENCES public.patients(patient_id),
  clinic_id TEXT NOT NULL REFERENCES public.clinics(clinic_id),
  doctor_id TEXT REFERENCES public.employees(employee_id),
  visit_date TIMESTAMPTZ DEFAULT now(),
  ticket_no SERIAL,
  queue_number TEXT,
  status_pembayaran TEXT DEFAULT '0' CHECK (status_pembayaran IN ('0','1','2')),
  status_periksa TEXT DEFAULT '0' CHECK (status_periksa IN ('0','1')),
  status_keluar TEXT DEFAULT '0' CHECK (status_keluar IN ('0','1')),
  description TEXT,
  visit_type TEXT NOT NULL DEFAULT 'rawat_jalan' CHECK (visit_type IN ('rawat_jalan','rawat_inap','igd')),
  payor_id TEXT REFERENCES public.payors(payor_id),
  in_date TIMESTAMPTZ DEFAULT now(),
  exit_date TIMESTAMPTZ,
  call_times INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.queue_numbers (
  id SERIAL PRIMARY KEY,
  queue_date DATE DEFAULT CURRENT_DATE,
  queue_number TEXT NOT NULL,
  clinic_id TEXT NOT NULL REFERENCES public.clinics(clinic_id),
  patient_id TEXT REFERENCES public.patients(patient_id),
  visit_id TEXT REFERENCES public.patient_visitations(visit_id),
  status TEXT DEFAULT 'waiting' CHECK (status IN ('waiting','called','in_progress','completed','cancelled')),
  called_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 4. CLINICAL
-- ============================================
CREATE TABLE public.assessments (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  subjective TEXT,
  objective TEXT,
  height NUMERIC,
  weight NUMERIC,
  blood_pressure_sistolik INTEGER,
  blood_pressure_diastolik INTEGER,
  heart_rate INTEGER,
  temperature NUMERIC,
  respiratory_rate INTEGER,
  gcs INTEGER,
  spo2 INTEGER,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.cppt (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  waktu_masuk TIMESTAMPTZ DEFAULT now(),
  subyektif TEXT,
  obyektif TEXT,
  assessment TEXT,
  planning TEXT,
  instruksi TEXT,
  created_by UUID REFERENCES public.profiles(id),
  edited_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.patient_diagnoses (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  diagnosis_id TEXT NOT NULL REFERENCES public.diagnoses(diagnosis_id),
  diagnosis_type TEXT DEFAULT 'primer',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 5. LABORATORY
-- ============================================
CREATE TABLE public.lab_orders (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  catalog_id INTEGER REFERENCES public.lab_test_catalog(id),
  test_name TEXT NOT NULL,
  category TEXT,
  order_date TIMESTAMPTZ DEFAULT now(),
  status TEXT DEFAULT 'ordered' CHECK (status IN ('ordered','in_progress','completed','cancelled')),
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  completed_at TIMESTAMPTZ
);

CREATE TABLE public.lab_analysis (
  id SERIAL PRIMARY KEY,
  lab_order_id INTEGER NOT NULL REFERENCES public.lab_orders(id) ON DELETE CASCADE,
  analysis_name TEXT NOT NULL,
  category TEXT,
  normal_value TEXT,
  result TEXT,
  unit TEXT,
  method TEXT,
  flag TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 6. PHARMACY
-- ============================================
CREATE TABLE public.drug_stock_logs (
  id SERIAL PRIMARY KEY,
  drug_id TEXT NOT NULL REFERENCES public.drugs(drug_id),
  change_type TEXT CHECK (change_type IN ('in','out','adjustment')),
  quantity INTEGER NOT NULL,
  reference TEXT,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.prescriptions (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  prescription_type TEXT DEFAULT 'rajal' CHECK (prescription_type IN ('rajal','ranap')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','dispensed','cancelled')),
  doctor_id TEXT REFERENCES public.employees(employee_id),
  notes TEXT,
  dispensed_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  dispensed_at TIMESTAMPTZ
);

CREATE TABLE public.prescription_items (
  id SERIAL PRIMARY KEY,
  prescription_id INTEGER NOT NULL REFERENCES public.prescriptions(id) ON DELETE CASCADE,
  drug_id TEXT NOT NULL REFERENCES public.drugs(drug_id),
  quantity INTEGER NOT NULL,
  dosage TEXT,
  frequency TEXT,
  duration TEXT,
  instruction TEXT,
  unit_price NUMERIC DEFAULT 0,
  total_price NUMERIC DEFAULT 0,
  is_dispensed BOOLEAN DEFAULT false
);

-- ============================================
-- 7. BILLING
-- ============================================
CREATE TABLE public.treatment_bills (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id) ON DELETE CASCADE,
  tariff_id TEXT NOT NULL REFERENCES public.tariffs(tariff_id),
  quantity INTEGER DEFAULT 1,
  unit_price NUMERIC DEFAULT 0,
  amount NUMERIC DEFAULT 0,
  description TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.billing_invoices (
  invoice_id TEXT PRIMARY KEY DEFAULT ('INV-' || upper(substr(md5(random()::text), 1, 8))),
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id),
  total_amount NUMERIC DEFAULT 0,
  discount NUMERIC DEFAULT 0,
  net_amount NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'unpaid' CHECK (status IN ('unpaid','paid','partial','cancelled')),
  paid_amount NUMERIC DEFAULT 0,
  payment_method TEXT,
  payment_note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  paid_at TIMESTAMPTZ
);

-- ============================================
-- 8. INTEGRATION
-- ============================================
CREATE TABLE public.satusehat_tokens (
  id SERIAL PRIMARY KEY,
  access_token TEXT NOT NULL,
  token_type TEXT DEFAULT 'Bearer',
  expires_at TIMESTAMPTZ NOT NULL,
  org_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.integrasi_satusehat (
  id SERIAL PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES public.patient_visitations(visit_id),
  patient_fhir_id TEXT,
  location_fhir_id TEXT,
  practitioner_fhir_id TEXT,
  encounter_fhir_id TEXT,
  condition_main_fhir_id TEXT,
  observation_sistolik NUMERIC,
  observation_diastolik NUMERIC,
  observation_suhu NUMERIC,
  observation_nadi INTEGER,
  observation_rr INTEGER,
  observation_gcs INTEGER,
  observation_tb NUMERIC,
  observation_bb NUMERIC,
  status JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.bpjs_references (
  id SERIAL PRIMARY KEY,
  ref_type TEXT NOT NULL,
  bpjs_code TEXT NOT NULL,
  local_code TEXT,
  name TEXT NOT NULL,
  metadata JSONB,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 9. AUDIT LOG
-- ============================================
CREATE TABLE public.audit_logs (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id),
  action TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id TEXT,
  old_data JSONB,
  new_data JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_visitations_patient ON public.patient_visitations(patient_id);
CREATE INDEX idx_visitations_clinic ON public.patient_visitations(clinic_id);
CREATE INDEX idx_visitations_date ON public.patient_visitations(visit_date);
CREATE INDEX idx_visitations_type ON public.patient_visitations(visit_type);
CREATE INDEX idx_visitations_status ON public.patient_visitations(status_periksa, status_pembayaran);
CREATE INDEX idx_cppt_visit ON public.cppt(visit_id);
CREATE INDEX idx_lab_orders_visit ON public.lab_orders(visit_id);
CREATE INDEX idx_lab_orders_status ON public.lab_orders(status);
CREATE INDEX idx_prescriptions_visit ON public.prescriptions(visit_id);
CREATE INDEX idx_prescriptions_status ON public.prescriptions(status);
CREATE INDEX idx_treatment_bills_visit ON public.treatment_bills(visit_id);
CREATE INDEX idx_billing_visit ON public.billing_invoices(visit_id);
CREATE INDEX idx_drugs_stock ON public.drugs(stock);
CREATE INDEX idx_drugs_category ON public.drugs(category);
CREATE INDEX idx_diagnoses_code ON public.diagnoses(code);
CREATE INDEX idx_patient_nik ON public.patients(nik);
CREATE INDEX idx_patient_no_rm ON public.patients(no_rm);
CREATE INDEX idx_patient_name ON public.patients(full_name);
CREATE INDEX idx_tariffs_category ON public.tariffs(category);
CREATE INDEX idx_queue_date ON public.queue_numbers(queue_date, clinic_id);
CREATE INDEX idx_queue_status ON public.queue_numbers(status);
CREATE INDEX idx_assessments_visit ON public.assessments(visit_id);
