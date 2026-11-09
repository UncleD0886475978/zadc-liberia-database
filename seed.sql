-- zadc-liberia-database — seed data
-- ============================================================================
-- DOCUMENTED HISTORICAL DATA: the funders, programs, projects, budgets,
-- dates and headline counts below reproduce ZADC's documented track record
-- from UN agency and ReliefWeb situation / project reports on Liberia,
-- 2004–2008. They are historical records, not live operational data.
--
-- HONESTY NOTE on communities: the source reports name the districts
-- (Saclepea-Mah, Yarwein-Mehnsonnoh, the Ganta area of Nimba County) and the
-- NUMBER of communities served, but did not publish the individual community
-- names. The community rows below are therefore labeled placeholders
-- ("Nimba Community 1", "Saclepea-Mah Community 1", ...) so the documented
-- project counts can be represented without inventing real place names.
--
-- Rows explicitly marked SAMPLE (staff, volunteers, individual beneficiary
-- rows, expense line items) are illustrative examples in the right shape —
-- the documented totals they stand for are noted in comments.
-- ============================================================================

-- ---------- Geography: Nimba County ----------
INSERT INTO counties (id, name) VALUES (1, 'Nimba') ON CONFLICT (id) DO NOTHING;

INSERT INTO districts (id, county_id, name) VALUES
  (1, 1, 'Saclepea-Mah'),
  (2, 1, 'Yarwein-Mehnsonnoh'),
  (3, 1, 'Ganta')
ON CONFLICT (id) DO NOTHING;

-- Placeholder communities (see honesty note above).
-- IDs 1–6: the six Nimba communities of the 2004 ERF project (Ganta area).
INSERT INTO communities (id, district_id, name, population) VALUES
  (1, 3, 'Nimba Community 1', NULL),
  (2, 3, 'Nimba Community 2', NULL),
  (3, 3, 'Nimba Community 3', NULL),
  (4, 3, 'Nimba Community 4', NULL),
  (5, 3, 'Nimba Community 5', NULL),
  (6, 3, 'Nimba Community 6', NULL)
ON CONFLICT (id) DO NOTHING;

-- IDs 7–13: the seven Saclepea-Mah communities of the UNICEF partnership.
INSERT INTO communities (id, district_id, name, population) VALUES
  (7,  1, 'Saclepea-Mah Community 1', NULL),
  (8,  1, 'Saclepea-Mah Community 2', NULL),
  (9,  1, 'Saclepea-Mah Community 3', NULL),
  (10, 1, 'Saclepea-Mah Community 4', NULL),
  (11, 1, 'Saclepea-Mah Community 5', NULL),
  (12, 1, 'Saclepea-Mah Community 6', NULL),
  (13, 1, 'Saclepea-Mah Community 7', NULL)
ON CONFLICT (id) DO NOTHING;

-- IDs 14–15: placeholder communities for Yarwein-Mehnsonnoh (WFP project).
INSERT INTO communities (id, district_id, name, population) VALUES
  (14, 2, 'Yarwein-Mehnsonnoh Community 1', NULL),
  (15, 2, 'Yarwein-Mehnsonnoh Community 2', NULL)
ON CONFLICT (id) DO NOTHING;

-- ---------- Funders (documented) ----------
INSERT INTO funders (id, name, type, country) VALUES
  (1, 'Emergency Response Fund (ERF)', 'UN pooled fund', NULL),
  (2, 'UNICEF', 'UN agency', NULL),
  (3, 'World Food Programme (WFP)', 'UN agency', NULL),
  (4, 'UNOPS', 'UN agency', NULL)
ON CONFLICT (id) DO NOTHING;

-- ---------- Programs (documented areas of work) ----------
INSERT INTO programs (id, name, sector, description) VALUES
  (1, 'WASH (Water, Sanitation & Hygiene)', 'WASH',
   'Wells, latrines and hand pumps for communities, schools and health clinics.'),
  (2, 'Agriculture & Livelihoods', 'Agriculture',
   'Rehabilitation of tree crops and support to smallholder farmers.'),
  (3, 'Health & Hygiene Promotion', 'Health',
   'Hygiene promotion and community hygiene / water & sanitation committees.'),
  (4, 'Construction & Infrastructure', 'Construction',
   'Community infrastructure construction under contract.')
ON CONFLICT (id) DO NOTHING;

-- ---------- Projects (documented) ----------
INSERT INTO projects (id, name, funder_id, program_id, district_id, budget_usd, start_date, end_date, status) VALUES
  -- ERF grant US$87,378 (Oct 2004): 16 wells + 16 latrines in six Nimba communities.
  (1, 'Emergency Water & Sanitation — Six Nimba Communities', 1, 1, 3,
   87378.00, '2004-10-01', '2005-01-31', 'completed'),
  -- UNICEF partnership: 25 wells + 25 latrines, hygiene promotion, 14 committees,
  -- 7 communities of Saclepea-Mah District. No budget was published — NULL on purpose.
  (2, 'School & Clinic WASH and Hygiene Promotion — Saclepea-Mah', 2, 1, 1,
   NULL, NULL, NULL, 'completed'),
  -- WFP-supported rehabilitation of 2,400 acres of tree crops for 600 farmers (2004).
  (3, 'Tree Crop Rehabilitation — Yarwein-Mehnsonnoh', 3, 2, 2,
   NULL, '2004-01-01', '2004-12-31', 'completed'),
  -- UNOPS construction contract US$107,378.72 (2008).
  (4, 'Community Infrastructure Construction', 4, 4, 3,
   107378.72, '2008-01-01', '2008-12-31', 'completed')
ON CONFLICT (id) DO NOTHING;

-- ---------- Grants (documented amounts, matching projects 1 and 4) ----------
INSERT INTO donations_grants (funder_id, project_id, amount_usd, received_on, purpose)
SELECT 1, 1, 87378.00, '2004-10-01', 'ERF grant: emergency water & sanitation in six Nimba communities'
WHERE NOT EXISTS (SELECT 1 FROM donations_grants WHERE project_id = 1 AND funder_id = 1);
INSERT INTO donations_grants (funder_id, project_id, amount_usd, received_on, purpose)
SELECT 4, 4, 107378.72, '2008-01-01', 'UNOPS construction contract'
WHERE NOT EXISTS (SELECT 1 FROM donations_grants WHERE project_id = 4 AND funder_id = 4);

-- ---------- Infrastructure assets (documented counts) ----------
-- Project 1 (ERF): 16 wells across the 6 placeholder Nimba communities.
INSERT INTO infrastructure_assets (asset_type, community_id, project_id, status, installed_on, gps_note)
SELECT 'well', 1 + ((g - 1) % 6), 1, 'functional', DATE '2004-12-01',
       'Placeholder location — exact sites were not published in the source reports'
FROM generate_series(1, 16) AS g
WHERE NOT EXISTS (SELECT 1 FROM infrastructure_assets WHERE project_id = 1 AND asset_type = 'well');

-- Project 1 (ERF): 16 latrines across the same 6 communities.
INSERT INTO infrastructure_assets (asset_type, community_id, project_id, status, installed_on, gps_note)
SELECT 'latrine', 1 + ((g - 1) % 6), 1, 'functional', DATE '2004-12-01',
       'Placeholder location — exact sites were not published in the source reports'
FROM generate_series(1, 16) AS g
WHERE NOT EXISTS (SELECT 1 FROM infrastructure_assets WHERE project_id = 1 AND asset_type = 'latrine');

-- Project 1 (ERF): hand pumps fitted to the wells (16).
INSERT INTO infrastructure_assets (asset_type, community_id, project_id, status, installed_on, gps_note)
SELECT 'hand_pump', 1 + ((g - 1) % 6), 1, 'functional', DATE '2004-12-01',
       'Hand pump fitted to a project well'
FROM generate_series(1, 16) AS g
WHERE NOT EXISTS (SELECT 1 FROM infrastructure_assets WHERE project_id = 1 AND asset_type = 'hand_pump');

-- Project 2 (UNICEF): 25 wells across the 7 Saclepea-Mah communities (schools/clinics).
INSERT INTO infrastructure_assets (asset_type, community_id, project_id, status, installed_on, gps_note)
SELECT 'well', 7 + ((g - 1) % 7), 2, 'functional', NULL,
       'School / health clinic well — exact sites were not published in the source reports'
FROM generate_series(1, 25) AS g
WHERE NOT EXISTS (SELECT 1 FROM infrastructure_assets WHERE project_id = 2 AND asset_type = 'well');

-- Project 2 (UNICEF): 25 latrines across the same 7 communities.
INSERT INTO infrastructure_assets (asset_type, community_id, project_id, status, installed_on, gps_note)
SELECT 'latrine', 7 + ((g - 1) % 7), 2, 'functional', NULL,
       'School / health clinic latrine — exact sites were not published in the source reports'
FROM generate_series(1, 25) AS g
WHERE NOT EXISTS (SELECT 1 FROM infrastructure_assets WHERE project_id = 2 AND asset_type = 'latrine');

-- ---------- Committees (documented: 14 in the UNICEF communities) ----------
-- 7 hygiene committees + 7 water/sanitation committees, one pair per community.
INSERT INTO committees (name, type, community_id, formed_on, member_count)
SELECT 'Hygiene Committee — Saclepea-Mah Community ' || g, 'hygiene', 6 + g, NULL, NULL
FROM generate_series(1, 7) AS g
WHERE NOT EXISTS (SELECT 1 FROM committees WHERE type = 'hygiene');
INSERT INTO committees (name, type, community_id, formed_on, member_count)
SELECT 'Water & Sanitation Committee — Saclepea-Mah Community ' || g, 'water_sanitation', 6 + g, NULL, NULL
FROM generate_series(1, 7) AS g
WHERE NOT EXISTS (SELECT 1 FROM committees WHERE type = 'water_sanitation');

-- ---------- Beneficiaries ----------
-- DOCUMENTED TOTAL for project 3: 600 farmers / 2,400 acres of tree crops
-- rehabilitated (WFP-supported, 2004). Seeding all 600 individual rows would
-- bloat this demo, so 24 SAMPLE farmer rows stand in for the documented 600.
INSERT INTO beneficiaries (household_head, community_id, project_id, household_size, beneficiary_type, registered_on)
SELECT 'Sample Farmer ' || lpad(g::text, 2, '0'), 14 + ((g - 1) % 2), 3, 6, 'farmer', DATE '2004-03-01'
FROM generate_series(1, 24) AS g
WHERE NOT EXISTS (SELECT 1 FROM beneficiaries WHERE project_id = 3);

-- SAMPLE household beneficiaries for the ERF water project (project 1).
INSERT INTO beneficiaries (household_head, community_id, project_id, household_size, beneficiary_type, registered_on)
SELECT 'Sample Household ' || lpad(g::text, 2, '0'), 1 + ((g - 1) % 6), 1, 5, 'household', DATE '2004-11-01'
FROM generate_series(1, 12) AS g
WHERE NOT EXISTS (SELECT 1 FROM beneficiaries WHERE project_id = 1);

-- SAMPLE household beneficiaries for the UNICEF WASH project (project 2) — one per community.
INSERT INTO beneficiaries (household_head, community_id, project_id, household_size, beneficiary_type, registered_on)
SELECT 'Sample Household (school/clinic) ' || g, 6 + g, 2, 5, 'household', NULL
FROM generate_series(1, 7) AS g
WHERE NOT EXISTS (SELECT 1 FROM beneficiaries WHERE project_id = 2);

-- ---------- Staff & volunteers (SAMPLE rows — illustrative only) ----------
INSERT INTO staff (full_name, role, district_id, email, phone, active)
SELECT 'Sample Program Manager', 'Program Manager', 3, NULL, NULL, TRUE
WHERE NOT EXISTS (SELECT 1 FROM staff);
INSERT INTO staff (full_name, role, district_id, email, phone, active) VALUES
  ('Sample WASH Officer', 'WASH Officer', 1, NULL, NULL, TRUE),
  ('Sample Field Coordinator', 'Field Coordinator', 3, NULL, NULL, TRUE),
  ('Sample Agriculture Extension Worker', 'Agriculture Extension Worker', 2, NULL, NULL, FALSE)
ON CONFLICT DO NOTHING;

INSERT INTO volunteers (full_name, community_id, role, phone)
SELECT 'Sample Volunteer ' || g, 6 + ((g - 1) % 7) + 1, 'Hygiene promoter', NULL
FROM generate_series(1, 6) AS g
WHERE NOT EXISTS (SELECT 1 FROM volunteers);

-- ---------- Expenses (SAMPLE line items against the documented projects) ----------
INSERT INTO expenses (project_id, category, amount_usd, spent_on, description)
SELECT 1, 'Well drilling', 32000.00, '2004-11-15', 'Sample breakdown: drilling of project wells (project 1)'
WHERE NOT EXISTS (SELECT 1 FROM expenses WHERE project_id = 1);
INSERT INTO expenses (project_id, category, amount_usd, spent_on, description) VALUES
  (1, 'Materials', 21500.00, '2004-12-01', 'Sample breakdown: latrine slabs, hand pumps and fittings (project 1)'),
  (1, 'Hygiene promotion', 6400.00, '2004-12-15', 'Sample breakdown: community hygiene training (project 1)'),
  (4, 'Materials', 58000.00, '2008-05-01', 'Sample breakdown: construction materials (project 4)'),
  (4, 'Labor', 36000.00, '2008-07-01', 'Sample breakdown: construction labor (project 4)'),
  (4, 'Transport', 5400.00, '2008-06-01', 'Sample breakdown: materials transport (project 4)')
ON CONFLICT DO NOTHING;

-- ---------- Distributions (SAMPLE rows in documented project shapes) ----------
INSERT INTO distributions (project_id, community_id, item, quantity, distributed_on)
SELECT 1, 1 + ((g - 1) % 6), 'Hygiene kit', 40, DATE '2004-12-10'
FROM generate_series(1, 6) AS g
WHERE NOT EXISTS (SELECT 1 FROM distributions WHERE project_id = 1);
INSERT INTO distributions (project_id, community_id, item, quantity, distributed_on)
SELECT 3, 14 + ((g - 1) % 2), 'Tree crop seedlings / farm tools (sample)', 100, DATE '2004-04-01'
FROM generate_series(1, 2) AS g
WHERE NOT EXISTS (SELECT 1 FROM distributions WHERE project_id = 3);
