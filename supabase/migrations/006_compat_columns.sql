-- Migration: Add no_rm column to patients
-- =============================================
-- The actual Supabase database uses 'no_registration' as the patient
-- identifier, but the app code references 'no_rm'. This migration adds
-- an 'no_rm' column for backwards compatibility and syncs existing data.

-- ============================================
-- Add no_rm column to patients
-- ============================================
ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS no_rm TEXT;

-- Sync existing data: copy no_registration to no_rm where no_rm is NULL
UPDATE public.patients
  SET no_rm = no_registration
  WHERE no_rm IS NULL AND no_registration IS NOT NULL;

-- Add unique constraint if not exists
ALTER TABLE public.patients
  ADD CONSTRAINT patients_no_rm_unique UNIQUE (no_rm);

-- ============================================
-- Add missing columns from app expectations
-- ============================================
ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS rt TEXT,
  ADD COLUMN IF NOT EXISTS rw TEXT,
  ADD COLUMN IF NOT EXISTS village TEXT,
  ADD COLUMN IF NOT EXISTS district TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS province TEXT;

-- ============================================
-- Add missing columns to clinics (queue_prefix, max_queue_daily)
-- ============================================
ALTER TABLE public.clinics
  ADD COLUMN IF NOT EXISTS queue_prefix TEXT DEFAULT 'A',
  ADD COLUMN IF NOT EXISTS max_queue_daily INTEGER DEFAULT 50;

-- ============================================
-- Add missing columns to patient_visitations
-- ============================================
ALTER TABLE public.patient_visitations
  ADD COLUMN IF NOT EXISTS queue_number TEXT,
  ADD COLUMN IF NOT EXISTS ticket_no INTEGER;
