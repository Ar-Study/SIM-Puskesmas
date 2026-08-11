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

async function migrate() {
  const client = await pool.connect();
  try {
    const migrationFile = join(__dirname, '..', 'supabase', 'migrations', '001_initial_schema.sql');
    const sql = readFileSync(migrationFile, 'utf8');
    console.log('Running migration...');
    await client.query(sql);
    console.log('Migration completed successfully!');
  } catch (err) {
    console.error('Migration failed:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
