<div align="center">

<img src="./logo.svg" width="190" alt="ZADC — Zao Development Organization, Liberia logo"/>

# 🌍 zadc-liberia-database

### The database of ZADC Inc. Liberia — "Zao Development Organization" — a national Liberian NGO, running on PostgreSQL 16 in one command.

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-StatefulSet-326CE5?logo=kubernetes&logoColor=white)
![Liberia](https://img.shields.io/badge/Liberia-Nimba%20County-success)
![Business Builds](https://img.shields.io/badge/Project-Business%20Builds-blue)

</div>

---

## 🏛️ The organization

**ZADC Inc. Liberia — "Zao Development Organization"** (historical full name:
**Zao Development Council Inc.**) is a national Liberian NGO based in
**Nimba County (Ganta), Liberia**. It is documented in UN agency and
ReliefWeb reporting from **1997–2008** working in **WASH** (water,
sanitation & hygiene), **agriculture**, **health & hygiene promotion** and
**construction**.

This repo gives that work a proper database: counties, districts and
communities; programs and funders; projects, staff, volunteers and
committees; the wells, latrines and hand pumps built; the grants received;
and the people reached — seeded with ZADC's documented historical projects
so the reports below run against the real track record, not toy data.

### 📜 Documented track record (seeded in `seed.sql`)

| When | Partner | What happened |
|---|---|---|
| Oct 2004 – Jan 2005 | **Emergency Response Fund (ERF)** — US$87,378 | **16 wells + 16 latrines** with hand pumps in **six Nimba communities** |
| (partnership) | **UNICEF** | **25 wells + 25 latrines** for schools & health clinics, hygiene promotion, and **14 community committees** (7 hygiene + 7 water/sanitation) in **7 communities of Saclepea-Mah District** |
| 2004 | **World Food Programme (WFP)** | Rehabilitation of **2,400 acres of tree crops** for **600 farmers** in **Yarwein-Mehnsonnoh District** |
| 2008 | **UNOPS** — US$107,378.72 | Community infrastructure **construction** contract |
| 2007 | — | Named **one of 8 NGOs preselected on standby** for emergency WASH response |

> **Honesty note:** the seed data reproduces these documented historical
> projects. The source reports name the districts and the counts, but did
> **not** publish the individual community names — so seeded community rows
> are labeled placeholders (`Nimba Community 1`, `Saclepea-Mah Community 1`,
> …), and rows like staff, volunteers and individual beneficiaries are
> marked **sample** in the SQL. Documented totals (600 farmers / 2,400
> acres) are noted in comments where a sample stands in for the full count.

## 🌟 What you get

| Feature | What you get |
|---|---|
| 🚀 **One-command bootstrap** | `./setup.sh` **installs its own prerequisites** on a fresh Ubuntu/Debian VM (base tools via apt, Docker via get.docker.com, kubectl from dl.k8s.io), starts the DB, loads schema + seed, and runs the reports |
| 🐘 **Full nonprofit schema** | **14 tables** (`schema.sql`): counties, districts, communities, programs, funders, projects, staff, volunteers, committees, beneficiaries, infrastructure_assets, donations_grants, expenses, distributions — with foreign keys and status/type checks |
| 📚 **Documented seed data** | `seed.sql` loads the four documented historical projects, their funders, grants (US$87,378 ERF + US$107,378.72 UNOPS), 41 wells, 41 latrines, 16 hand pumps and 14 committees |
| 📊 **Built-in report queries** | The installer finishes by running three real reports: **infrastructure assets by community**, **funding by funder**, and **beneficiaries by project** |
| 🐳 **Docker mode** | Compose stack (`postgres:16-alpine`) with a named volume, native healthcheck, and safe change-me defaults in `.env` |
| ☸️ **Kubernetes mode** | `./setup.sh k8s` — StatefulSet + 10Gi PVC + Secret + ClusterIP & headless Services in the `zadc` namespace |
| 💾 **Persistent data** | Your data survives restarts in both modes (Docker volume / Kubernetes PVC); `down` keeps the data |

## 🏗️ How it fits together

```
   Docker mode                          Kubernetes mode
┌──────────────┐                     ┌─────────────────────────────┐
│  your app /  │                     │  namespace: zadc            │
│  psql        │                     │                             │
└──────┬───────┘                     │  Service ──▶ StatefulSet    │
       │ localhost:5432              │               │             │
┌──────▼───────┐                     │               ▼             │
│  PostgreSQL 16│                     │        PVC (10Gi storage)   │
│  container   │                     └─────────────────────────────┘
└──────┬───────┘
       ▼
  named volume (data)
   schema.sql + seed.sql are piped in by setup.sh in both modes
```

## ✅ Requirements

- **A fresh Ubuntu/Debian VM is all you need** — `setup.sh` installs git,
  curl, Docker (and kubectl for k8s mode) itself. Non-apt platforms get
  printed install guidance instead.
- **Kubernetes mode:** any cluster for `kubectl` to point at (minikube,
  kind, Docker Desktop, EKS, AKS, or GKE).
- No cloud account, no API keys.

## 🚀 Quick start

**One-liner — fresh VM, nothing installed:**

```bash
curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/zadc-liberia-database/main/setup.sh | bash
```

**Docker — from a checkout:**

```bash
./setup.sh          # same as ./setup.sh docker
```

**Kubernetes — one command:**

```bash
./setup.sh k8s
```

Both modes print your connection info when they're done, after loading the
schema and seed data and running the three report queries. First Docker run
pulls the `postgres:16-alpine` image, so give it a minute.

**Stop it (data is kept):**

```bash
./setup.sh down
```

## 🔌 Connect

```bash
# psql (from your machine)
psql postgresql://zadc:zadc_change_me@localhost:5432/zadc

# or inside the running container
docker compose exec db psql -U zadc -d zadc
```

On Kubernetes, port-forward first (leave it running), then use the same command as above:

```bash
kubectl -n zadc port-forward svc/zadc-postgresql 5432:5432
# then: psql postgresql://zadc:zadc_change_me@localhost:5432/zadc
```

Try the reports yourself:

```sql
-- Infrastructure assets by community
SELECT c.name, a.asset_type, count(*) FROM infrastructure_assets a
JOIN communities c ON c.id = a.community_id GROUP BY c.name, a.asset_type;

-- Funding by funder
SELECT f.name, sum(g.amount_usd) FROM donations_grants g
JOIN funders f ON f.id = g.funder_id GROUP BY f.name;

-- Beneficiaries by project
SELECT p.name, count(*) FROM beneficiaries b
JOIN projects p ON p.id = b.project_id GROUP BY p.name;
```

> ⚠️ The default password is `zadc_change_me` — fine at home, **change it**
> in `.env` (Docker) or `k8s/secret.yaml` (Kubernetes) for anything real.

## 📁 Project layout

```
zadc-liberia-database/
├── setup.sh              # THE bootstrap script: docker | k8s | down — installs prerequisites, loads data, runs reports
├── docker-compose.yml    # PostgreSQL 16 + named volume + healthcheck
├── .env.example          # db / user / password / port (change-me defaults)
├── schema.sql            # 14-table nonprofit schema (FKs + checks)
├── seed.sql              # documented historical projects (ERF / UNICEF / WFP / UNOPS)
├── k8s/
│   ├── namespace.yaml        # "zadc" namespace
│   ├── secret.example.yaml   # same credentials as .env.example
│   ├── pvc.yaml              # 10Gi persistent storage
│   ├── statefulset.yaml      # the database, with native readiness/liveness probes
│   └── service.yaml          # ClusterIP + headless service
└── README.md
```

## 👨‍👩‍👧 Sibling repos — Business Builds

Themed business databases & cloud environments, same bootstrap pattern:

- [clothing-store-database](https://github.com/UncleD0886475978/clothing-store-database) — MySQL store database for Threads & Co. apparel
- [fast-food-database](https://github.com/UncleD0886475978/fast-food-database) — MongoDB fast-food database
- [nursing-home-eks](https://github.com/UncleD0886475978/nursing-home-eks) — nursing home environment on AWS EKS
- [it-services-aks](https://github.com/UncleD0886475978/it-services-aks) — IT services environment on Azure AKS
- [clothing-store-gke](https://github.com/UncleD0886475978/clothing-store-gke) — clothing store environment on Google Cloud GKE

## 🎨 Logo

No historical ZADC logo was found in the UN / ReliefWeb record or anywhere
online (the organization has no modern website, and its 1997–2008 reporting
is text-only) — so the logo in this repo (`logo.svg`) is a
**new mark created for this project**, not a reproduction of an original.
It combines a water droplet and green sprout — ZADC's WASH and agriculture
work — with a single gold star for Liberia, ringed by the organization's
name and its home, Nimba County.

## 📚 Sources

The organizational history and project figures in this README and in
`seed.sql` come from **UN agency and ReliefWeb situation / project reports
on Liberia, 2004–2008** (reporting on the Emergency Response Fund grant of
October 2004, UNICEF WASH partnership activities in Saclepea-Mah District,
WFP-supported tree-crop rehabilitation in Yarwein-Mehnsonnoh District, the
2008 UNOPS construction contract, and the 2007 standby emergency-response
NGO preselection). Figures are reproduced as reported; where a report gave
no budget (UNICEF, WFP projects), the database honestly stores `NULL`.

## 🗺️ Roadmap

- [x] One-command bootstrap install (Docker + Kubernetes) that installs its own prerequisites
- [x] 14-table nonprofit schema with documented historical seed data
- [x] Built-in report queries (assets by community, funding by funder, beneficiaries by project)
- [ ] Data-entry forms / simple web UI for field staff
- [ ] Asset condition tracking (functional / needs-repair surveys)
- [ ] Backups (scheduled dumps to object storage)
- [ ] TLS + real secrets management

---

<div align="center">

**ZADC Inc. Liberia — clean water, working farms, stronger communities in Nimba County.** 🌍

</div>
