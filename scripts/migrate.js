import pg from 'pg';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const SUPABASE_PASSWORD = process.env.SUPABASE_PASSWORD || 'S1mRS.S1mRS';

const pool = new pg.Pool({
  host: 'db.iwqgnjxskbhmhmojhifr.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: SUPABASE_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

const MIGRATIONS = [
  '001_initial_schema.sql',
  '002_seed_data.sql',
  '003_rls_policies.sql',
  '004_poli_bpjs.sql',
  '005_fix_profile_trigger.sql',
  '006_compat_columns.sql'
];

async function migrate() {
  const client = await pool.connect();
  try {
    const migrationsDir = join(__dirname, '..', 'supabase', 'migrations');

    for (const file of MIGRATIONS) {
      const sql = readFileSync(join(migrationsDir, file), 'utf8');
      console.log(`Running migration ${file}...`);
      await client.query(sql);
      console.log(`  ${file} OK`);
    }

    console.log('All migrations completed successfully!');
  } catch (err) {
    console.error('Migration failed:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
