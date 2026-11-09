import 'dotenv/config';
import fs from 'node:fs/promises';
import pg from 'pg';
const db = new pg.Pool({connectionString: process.env.DATABASE_URL, ssl: process.env.DATABASE_URL?.includes('localhost') ? false : {rejectUnauthorized: true}});
try { await db.query(await fs.readFile(new URL('./schema.sql',import.meta.url),'utf8')); console.log('Schema applied'); }
finally { await db.end(); }
