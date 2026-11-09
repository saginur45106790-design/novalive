import 'dotenv/config';
import bcrypt from 'bcryptjs';
import pg from 'pg';
const email = process.env.ADMIN_BOOTSTRAP_EMAIL?.trim().toLowerCase();
const pass = process.env.ADMIN_BOOTSTRAP_PASSWORD;
if (!email || !pass || pass.length < 16) throw new Error('Set ADMIN_BOOTSTRAP_EMAIL and a password of at least 16 characters');
const db = new pg.Pool({connectionString:process.env.DATABASE_URL, ssl:process.env.DATABASE_URL?.includes('localhost')?false:{rejectUnauthorized:true}});
try {
  const hash = await bcrypt.hash(pass, 12);
  const result = await db.query('INSERT INTO users(name,email,password_hash,role,age_confirmed) VALUES ($1,$2,$3,$4,true) ON CONFLICT(email) DO NOTHING RETURNING id', ['Owner',email,hash,'admin']);
  if (!result.rowCount) throw new Error('That email exists. Bootstrap does not promote existing accounts.');
  console.log('Admin account created:',email);
} finally { await db.end(); }
