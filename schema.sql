-- zadc-liberia-database — PostgreSQL 16 schema
-- ZADC Inc. Liberia ("Zao Development Organization"; historical full name:
-- Zao Development Council Inc.) — a national Liberian NGO based in Nimba
-- County (Ganta), working in WASH, agriculture, health/hygiene promotion
-- and construction.
--
-- Idempotent-ish: every table uses CREATE TABLE IF NOT EXISTS, so re-running
-- this file against an existing database is safe.
-- Load order in setup.sh: schema.sql first, then seed.sql.

CREATE TABLE IF NOT EXISTS counties (
  id   SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS districts (
  id        SERIAL PRIMARY KEY,
  county_id INTEGER NOT NULL REFERENCES counties(id),
  name      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS communities (
  id          SERIAL PRIMARY KEY,
  district_id INTEGER NOT NULL REFERENCES districts(id),
  name        TEXT NOT NULL,
  population  INTEGER
);

CREATE TABLE IF NOT EXISTS programs (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  sector      TEXT,
  description TEXT
);

CREATE TABLE IF NOT EXISTS funders (
  id      SERIAL PRIMARY KEY,
  name    TEXT NOT NULL UNIQUE,
  type    TEXT,
  country TEXT
);

CREATE TABLE IF NOT EXISTS projects (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  funder_id   INTEGER REFERENCES funders(id),
  program_id  INTEGER REFERENCES programs(id),
  district_id INTEGER REFERENCES districts(id),
  budget_usd  NUMERIC(12,2),
  start_date  DATE,
  end_date    DATE,
  status      TEXT NOT NULL DEFAULT 'planned'
);

CREATE TABLE IF NOT EXISTS staff (
  id          SERIAL PRIMARY KEY,
  full_name   TEXT NOT NULL,
  role        TEXT,
  district_id INTEGER REFERENCES districts(id),
  email       TEXT,
  phone       TEXT,
  active      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS volunteers (
  id           SERIAL PRIMARY KEY,
  full_name    TEXT NOT NULL,
  community_id INTEGER REFERENCES communities(id),
  role         TEXT,
  phone        TEXT
);

CREATE TABLE IF NOT EXISTS committees (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  type         TEXT NOT NULL CHECK (type IN ('hygiene', 'water_sanitation')),
  community_id INTEGER NOT NULL REFERENCES communities(id),
  formed_on    DATE,
  member_count INTEGER
);

CREATE TABLE IF NOT EXISTS beneficiaries (
  id              SERIAL PRIMARY KEY,
  household_head  TEXT NOT NULL,
  community_id    INTEGER REFERENCES communities(id),
  project_id      INTEGER REFERENCES projects(id),
  household_size  INTEGER,
  beneficiary_type TEXT NOT NULL DEFAULT 'household'
                     CHECK (beneficiary_type IN ('household', 'farmer')),
  registered_on   DATE
);

CREATE TABLE IF NOT EXISTS infrastructure_assets (
  id           SERIAL PRIMARY KEY,
  asset_type   TEXT NOT NULL CHECK (asset_type IN ('well', 'latrine', 'hand_pump')),
  community_id INTEGER NOT NULL REFERENCES communities(id),
  project_id   INTEGER REFERENCES projects(id),
  status       TEXT NOT NULL DEFAULT 'functional'
                 CHECK (status IN ('functional', 'needs_repair', 'non_functional')),
  installed_on DATE,
  gps_note     TEXT
);

CREATE TABLE IF NOT EXISTS donations_grants (
  id          SERIAL PRIMARY KEY,
  funder_id   INTEGER NOT NULL REFERENCES funders(id),
  project_id  INTEGER REFERENCES projects(id),
  amount_usd  NUMERIC(12,2),
  received_on DATE,
  purpose     TEXT
);

CREATE TABLE IF NOT EXISTS expenses (
  id          SERIAL PRIMARY KEY,
  project_id  INTEGER NOT NULL REFERENCES projects(id),
  category    TEXT,
  amount_usd  NUMERIC(12,2) NOT NULL,
  spent_on    DATE,
  description TEXT
);

CREATE TABLE IF NOT EXISTS distributions (
  id           SERIAL PRIMARY KEY,
  project_id   INTEGER NOT NULL REFERENCES projects(id),
  community_id INTEGER NOT NULL REFERENCES communities(id),
  item         TEXT NOT NULL,
  quantity     INTEGER NOT NULL DEFAULT 1,
  distributed_on DATE
);
