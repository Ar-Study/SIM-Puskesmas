import { supabase } from './supabase';

export async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export async function getCurrentUser() {
  try {
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return null;

    let profile = null;
    try {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();
      profile = data;
    } catch (e) {
      console.warn('Profile fetch failed (table may not exist):', e.message);
    }

    if (!profile) {
      const fallback = {
        id: user.id,
        full_name: user.email?.split('@')[0] || 'User',
        role: 'admin',
        employee_id: null,
        is_active: true,
        profilePersisted: false
      };

      // Try to persist the profile in the database
      const { data: upserted, error: upsertErr } = await supabase
        .from('profiles')
        .upsert(fallback, { onConflict: 'id' })
        .select()
        .single();

      if (upsertErr) {
        console.warn('Profile upsert failed (RLS may block INSERT on profiles):', upsertErr.message);
      } else {
        fallback.profilePersisted = true;
        Object.assign(fallback, upserted);
      }

      profile = fallback;
    } else {
      // Profile found in DB - it's persisted
      profile.profilePersisted = true;
    }

    return { ...user, profile };
  } catch (e) {
    console.error('getCurrentUser error:', e);
    return null;
  }
}

export async function getProfile(userId) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();
  if (error) throw error;
  return data;
}

export async function logAudit(action, tableName, recordId = null, oldData = null, newData = null) {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    await supabase.from('audit_logs').insert({
      user_id: user.id,
      action,
      table_name: tableName,
      record_id: recordId,
      old_data: oldData,
      new_data: newData
    });
  } catch (e) {
    console.warn('Audit log failed:', e.message);
  }
}

export function hasPermission(profile, permission) {
  if (!profile) return false;
  if (profile.role === 'admin') return true;
  const perms = {
    registrasi: ['patients', 'visitations', 'queue_numbers', 'online_registrations'],
    dokter: ['cppt', 'diagnoses', 'prescriptions', 'lab_orders', 'tariffs', 'treatment_bills', 'assessments'],
    perawat: ['assessments', 'cppt'],
    apoteker: ['prescriptions_dispense', 'drugs', 'drug_stock_logs'],
    lab_teknis: ['lab_orders', 'lab_analysis'],
    kasir: ['billing_invoices', 'treatment_bills'],
    bidan: ['cppt', 'assessments', 'prescriptions']
  };
  return perms[profile.role]?.includes(permission) ?? false;
}
