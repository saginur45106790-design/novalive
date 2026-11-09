CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(80) NOT NULL,
  email varchar(255) NOT NULL UNIQUE,
  password_hash text NOT NULL,
  role varchar(16) NOT NULL DEFAULT 'user' CHECK (role IN ('user','host','admin')),
  age_confirmed boolean NOT NULL DEFAULT false,
  suspended boolean NOT NULL DEFAULT false,
  coins bigint NOT NULL DEFAULT 0 CHECK (coins >= 0),
  earnings bigint NOT NULL DEFAULT 0 CHECK (earnings >= 0),
  bio varchar(400) NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users(id),
  kind varchar(16) NOT NULL CHECK (kind IN ('live','party','private')),
  title varchar(100) NOT NULL,
  status varchar(16) NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_rooms_kind ON rooms(kind,status,created_at DESC);
CREATE TABLE IF NOT EXISTS calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  caller_id uuid NOT NULL REFERENCES users(id),
  callee_id uuid NOT NULL REFERENCES users(id),
  room_id uuid NOT NULL UNIQUE REFERENCES rooms(id),
  status varchar(16) NOT NULL DEFAULT 'ringing' CHECK (status IN ('ringing','accepted','rejected','ended')),
  started_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  CHECK (caller_id <> callee_id)
);
CREATE INDEX IF NOT EXISTS ix_calls_callee ON calls(callee_id,status,created_at DESC);
CREATE TABLE IF NOT EXISTS blocks (
  owner_id uuid REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (owner_id, blocked_id), CHECK (owner_id <> blocked_id)
);
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES users(id),
  recipient_id uuid NOT NULL REFERENCES users(id),
  body varchar(2000) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_messages_users ON messages(sender_id,recipient_id,created_at DESC);
CREATE TABLE IF NOT EXISTS reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES users(id),
  target_id uuid NOT NULL REFERENCES users(id),
  reason varchar(250) NOT NULL,
  state varchar(16) NOT NULL DEFAULT 'open' CHECK (state IN ('open','resolved')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  coin_delta bigint NOT NULL DEFAULT 0,
  earning_delta bigint NOT NULL DEFAULT 0,
  action varchar(40) NOT NULL,
  reference_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_ledger_user ON ledger(user_id,created_at DESC);
CREATE TABLE IF NOT EXISTS gifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES users(id),
  recipient_id uuid NOT NULL REFERENCES users(id),
  gift_key varchar(32) NOT NULL,
  price bigint NOT NULL CHECK(price > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS withdrawals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  points bigint NOT NULL CHECK(points > 0),
  payout_details varchar(250) NOT NULL,
  status varchar(16) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  settled_at timestamptz
);
CREATE TABLE IF NOT EXISTS audit_log (
  id bigserial PRIMARY KEY,
  actor_id uuid REFERENCES users(id),
  action varchar(80) NOT NULL,
  target_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
