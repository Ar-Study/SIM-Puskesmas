-- Migration: Fix Profile Auto-creation
-- =============================================
-- Auto-create a profiles row when a new auth.users row is inserted,
-- and grant authenticated users INSERT permission on profiles.

-- ============================================
-- Allow authenticated users to insert their own profile
-- (DROP IF EXISTS to make idempotent, then CREATE)
-- ============================================
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (id = auth.uid());

-- ============================================
-- Function to auto-create profile on signup
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, is_active)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    'registrasi',
    true
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- Trigger on auth.users
-- ============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- Backfill: create profile for existing users without one
-- ============================================
INSERT INTO public.profiles (id, full_name, role, is_active)
SELECT
  au.id,
  COALESCE(au.raw_user_meta_data->>'full_name', au.email),
  'admin',
  true
FROM auth.users au
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = au.id);
