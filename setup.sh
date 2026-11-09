#!/usr/bin/env bash
# setup.sh — zadc-liberia-database (ZADC Inc. Liberia — "Zao Development Organization")
# PostgreSQL 16 nonprofit database for a Liberian NGO: counties, districts,
# communities, programs, funders, projects, staff, committees, beneficiaries,
# wells/latrines/hand pumps, grants and expenses — seeded with ZADC's
# documented historical projects (UN / ReliefWeb reporting, 2004–2008).
#
# BOOTSTRAP script: on a fresh Ubuntu/Debian VM it INSTALLS its own
# prerequisites (base tools via apt, Docker via get.docker.com, kubectl via
# the official dl.k8s.io binary) instead of just checking for them.
#
# Usage:
#   ./setup.sh          # same as: ./setup.sh docker
#   ./setup.sh docker   # run PostgreSQL with Docker Compose + load schema/seed + reports
#   ./setup.sh k8s      # run PostgreSQL on Kubernetes (StatefulSet) + load schema/seed + reports
#   ./setup.sh down     # tear down (Docker Compose and/or Kubernetes; data kept)
#
# One-liner (fresh VM):
#   curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/zadc-liberia-database/main/setup.sh | bash
set -e

REPO_NAME="zadc-liberia-database"
REPO="zadc-liberia-database"
OWNER="UncleD0886475978"
REPO_URL="https://github.com/UncleD0886475978/${REPO_NAME}.git"
RUN_ONELINE="curl -fsSL https://raw.githubusercontent.com/${OWNER}/${REPO}/main/setup.sh | bash"
MODE="${1:-docker}"

# ---------- pretty output ----------
if [ -t 1 ]; then
  BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  BOLD=''; GREEN=''; CYAN=''; YELLOW=''; RED=''; NC=''
fi
step() { printf "\n${BOLD}${CYAN}==>${NC} ${BOLD}%s${NC}\n" "$*"; }
info() { printf "    %s\n" "$*"; }
ok()   { printf "${GREEN}  ✓ %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}  ! %s${NC}\n" "$*"; }
die()  { printf "${RED}  ✗ %s${NC}\n" "$*" >&2; exit 1; }

# ---------- defaults (must match .env.example / k8s secret example) ----------
DB_NAME="${DB_NAME:-zadc}"
DB_USER="${DB_USER:-zadc}"
DB_PASSWORD="${DB_PASSWORD:-zadc_change_me}"
DB_PORT="${DB_PORT:-5432}"
APP="zadc-postgresql"
NS="zadc"

load_env() { if [ -f .env ]; then set -a; . ./.env; set +a; fi; }

# ---------- Step 1: platform check + base bootstrap ----------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "ERROR: this script needs root or sudo to install packages."
    exit 1
  fi
fi
APT=0
if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then APT=1; fi
INSTALLED=""
APT_UPDATED=""
note_installed() { INSTALLED="${INSTALLED} $1"; }
apt_update_once() {
  if [ -z "${APT_UPDATED}" ]; then $SUDO apt-get update -y; APT_UPDATED=1; fi
}
apt_install() {
  apt_update_once
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$@"
}

bootstrap_base() {
  step "Step 1: Platform check + base bootstrap (git, curl, ca-certificates, gnupg)"
  if [ "${APT}" -ne 1 ]; then
    warn "Non-apt platform detected ($(uname -s)). This bootstrap script auto-installs only on Ubuntu/Debian."
    info "Install these manually, then re-run: git, curl, ca-certificates, gnupg,"
    info "Docker (https://docs.docker.com/get-docker/) and, for k8s mode, kubectl"
    info "(https://kubernetes.io/docs/tasks/tools/)."
    exit 1
  fi
  BASE_PKGS=""
  command -v git >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} git"
  command -v curl >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} curl"
  [ -f /etc/ssl/certs/ca-certificates.crt ] || BASE_PKGS="${BASE_PKGS} ca-certificates"
  command -v gpg >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} gnupg"
  if [ -n "${BASE_PKGS}" ]; then
    info "Installing base tools:${BASE_PKGS}"
    # shellcheck disable=SC2086
    apt_install ${BASE_PKGS}
    note_installed "${BASE_PKGS}"
  else
    ok "Base tools already present (git, curl, ca-certificates, gnupg)"
  fi
}

# ---------- Step 2: locate or clone the repo ----------
locate_repo() {
  step "Step 2: Locate the repo"
  if [ -f "$0" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  else
    SCRIPT_DIR="$PWD"
  fi
  if [ -f "${SCRIPT_DIR}/docker-compose.yml" ]; then
    REPO_DIR="$SCRIPT_DIR"
    info "Using repo checkout at: $REPO_DIR"
  elif [ -f "$PWD/docker-compose.yml" ]; then
    REPO_DIR="$PWD"
    info "Using repo checkout at: $REPO_DIR"
  else
    REPO_DIR="$HOME/repos/$REPO_NAME"
    if [ -d "$REPO_DIR/.git" ]; then
      info "Existing checkout found — pulling latest..."
      git -C "$REPO_DIR" pull --ff-only || true
    else
      if ! command -v git >/dev/null 2>&1; then
        die "git not found. Install git first: https://git-scm.com/downloads"
      fi
      info "Cloning $REPO_URL into $REPO_DIR ..."
      mkdir -p "$HOME/repos"
      git clone "$REPO_URL" "$REPO_DIR"
    fi
  fi
  cd "$REPO_DIR"
}

# ---------- Step 3: bootstrap Docker / kubectl ----------
DOCKER="docker"
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    info "docker: already present ($(docker --version))"
  elif [ "${APT}" -eq 1 ]; then
    info "Installing Docker Engine via the official get.docker.com script..."
    curl -fsSL https://get.docker.com | $SUDO sh
    note_installed "docker"
  else
    return 1
  fi
  if ! docker info >/dev/null 2>&1 && ! $SUDO docker info >/dev/null 2>&1; then
    info "Starting the Docker daemon..."
    $SUDO systemctl enable --now docker 2>/dev/null || $SUDO service docker start 2>/dev/null || true
    for _i in $(seq 1 15); do
      if docker info >/dev/null 2>&1 || $SUDO docker info >/dev/null 2>&1; then break; fi
      sleep 2
    done
  fi
  if docker info >/dev/null 2>&1; then
    DOCKER="docker"
  elif $SUDO docker info >/dev/null 2>&1; then
    DOCKER="sudo docker"
    if [ "$(id -u)" -ne 0 ]; then
      $SUDO usermod -aG docker "$USER" 2>/dev/null || true
      info "NOTE: you were added to the 'docker' group (applies at next login); this run uses 'sudo docker'."
    fi
  else
    die "Docker is installed but the daemon could not be started. On a VM: sudo systemctl start docker"
  fi
  ok "Docker daemon OK (using: ${DOCKER})"
}

need_docker() {
  step "Step 3: Bootstrap Docker"
  install_docker
  # shellcheck disable=SC2086
  if ! ${DOCKER} compose version >/dev/null 2>&1; then
    die "'docker compose' (v2 plugin) is not available. The get.docker.com installer normally includes it; on Debian/Ubuntu you can also run: sudo apt-get install -y docker-compose-plugin"
  fi
  ok "Docker + Compose found"
}

install_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    info "kubectl: already present ($(kubectl version --client --short 2>/dev/null || kubectl version --client))"
  elif [ "${APT}" -eq 1 ]; then
    info "Installing kubectl from the official dl.k8s.io binary..."
    KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/$(dpkg --print-architecture)/kubectl"
    $SUDO install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm -f /tmp/kubectl
    note_installed "kubectl"
  else
    return 1
  fi
}

need_kubectl() {
  step "Step 3: Bootstrap kubectl + check Kubernetes access"
  if ! install_kubectl; then
    die "could not auto-install kubectl on this platform. Install it manually: https://kubernetes.io/docs/tasks/tools/"
  fi
  if ! kubectl cluster-info >/dev/null 2>&1; then
    die "kubectl cannot reach a cluster. Start minikube / kind / Docker Desktop Kubernetes, or set your kubeconfig, then re-run. Easy local cluster: https://minikube.sigs.k8s.io/docs/start/"
  fi
  ok "kubectl connected to a cluster"
}

print_summary() {
  cat <<EOF

=================== BOOTSTRAP SUMMARY ===================
Installed during this run:${INSTALLED:- (nothing — all tools were already present)}
Working copy: ${REPO_DIR:-$PWD}
Next time, set up from scratch on any fresh Ubuntu VM with one line:
  ${RUN_ONELINE}
=========================================================
EOF
}

# ---------- report queries (shared by docker + k8s modes) ----------
REPORT_SQL="
SELECT '--- (a) Infrastructure assets by community ---' AS report;
SELECT c.name AS community, a.asset_type, count(*) AS assets
FROM infrastructure_assets a
JOIN communities c ON c.id = a.community_id
GROUP BY c.name, a.asset_type
ORDER BY c.name, a.asset_type;

SELECT '--- (b) Funding by funder ---' AS report;
SELECT f.name AS funder, sum(g.amount_usd) AS total_usd
FROM donations_grants g
JOIN funders f ON f.id = g.funder_id
GROUP BY f.name
ORDER BY f.name;

SELECT '--- (c) Beneficiaries by project ---' AS report;
SELECT p.name AS project, count(*) AS beneficiaries
FROM beneficiaries b
JOIN projects p ON p.id = b.project_id
GROUP BY p.name
ORDER BY p.name;
"

do_down() {
  step "Tearing down PostgreSQL (ZADC)"
  # Pick a working docker invocation without installing anything.
  DOCKER="docker"
  if ! docker info >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER="sudo docker"
  fi
  if command -v docker >/dev/null 2>&1 && ${DOCKER} compose version >/dev/null 2>&1 && [ -f docker-compose.yml ]; then
    load_env
    # shellcheck disable=SC2086
    ${DOCKER} compose down || true
    ok "Docker Compose stack stopped (data volume kept — add -v yourself if you really want it gone)"
  fi
  if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
    kubectl delete -f k8s/service.yaml -f k8s/statefulset.yaml -f k8s/pvc.yaml --ignore-not-found=true || true
    kubectl delete -f k8s/secret.yaml --ignore-not-found=true || true
    ok "Kubernetes resources deleted (namespace '${NS}' kept — delete it yourself if you really want it gone)"
  fi
  echo
  info "Done."
}

run_docker() {
  need_docker
  step "Preparing configuration"
  if [ ! -f .env ]; then cp .env.example .env; ok "Created .env from .env.example (edit it to change the password)"; else ok ".env already exists — using it"; fi
  load_env
  step "Starting PostgreSQL with Docker Compose"
  # shellcheck disable=SC2086
  ${DOCKER} compose up -d
  step "Waiting for PostgreSQL to accept connections"
  for i in $(seq 1 60); do
    # shellcheck disable=SC2086
    if ${DOCKER} compose exec -T db pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then ok "Database is ready"; break; fi
    if [ "$i" = "60" ]; then die "Database did not become ready in time. Check logs: ${DOCKER} compose logs db"; fi
    sleep 2
  done
  step "Loading schema (schema.sql)"
  # shellcheck disable=SC2086
  ${DOCKER} compose exec -T db psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < schema.sql
  ok "Schema loaded"
  step "Loading seed data — documented historical projects (seed.sql)"
  # shellcheck disable=SC2086
  ${DOCKER} compose exec -T db psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < seed.sql
  ok "Seed data loaded"
  step "Running report queries"
  # shellcheck disable=SC2086
  ${DOCKER} compose exec -T db psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "$REPORT_SQL"
  ok "Reports ran clean"
  print_docker_info
  print_summary
}

print_docker_info() {
  step "PostgreSQL is UP — connection info"
  info "Host:     localhost"
  info "Port:     $DB_PORT"
  info "Database: $DB_NAME"
  info "User:     $DB_USER"
  info "Password: $DB_PASSWORD   (from .env — change it for anything real)"
  info "Connect:  psql postgresql://$DB_USER:$DB_PASSWORD@localhost:$DB_PORT/$DB_NAME"
  info "Shell:    ${DOCKER} compose exec db psql -U $DB_USER -d $DB_NAME"
  echo
  info "Logs:  ${DOCKER} compose logs -f db"
  info "Stop:  ./setup.sh down        (or: ${DOCKER} compose down)"
}

run_k8s() {
  need_kubectl
  load_env
  step "Preparing Kubernetes manifests"
  if [ ! -f k8s/secret.yaml ]; then cp k8s/secret.example.yaml k8s/secret.yaml; ok "Created k8s/secret.yaml from the example (edit it to change the password)"; fi
  step "Applying manifests (namespace, secret, storage, StatefulSet, service)"
  kubectl apply -f k8s/namespace.yaml
  kubectl apply -f k8s/secret.yaml
  kubectl apply -f k8s/pvc.yaml
  kubectl apply -f k8s/statefulset.yaml
  kubectl apply -f k8s/service.yaml
  step "Waiting for the pod to be ready"
  kubectl -n "$NS" rollout status statefulset/"$APP" --timeout=300s
  ok "Pod is ready"
  step "Loading schema (schema.sql)"
  kubectl -n "$NS" exec -i statefulset/"$APP" -- psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < schema.sql
  ok "Schema loaded"
  step "Loading seed data — documented historical projects (seed.sql)"
  kubectl -n "$NS" exec -i statefulset/"$APP" -- psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < seed.sql
  ok "Seed data loaded"
  step "Running report queries"
  kubectl -n "$NS" exec statefulset/"$APP" -- psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -c "$REPORT_SQL"
  ok "Reports ran clean"
  step "PostgreSQL is UP on Kubernetes — how to connect"
  info "Port-forward (run this, leave it open):"
  info "  kubectl -n $NS port-forward svc/$APP 5432:5432"
  info "Then connect from another terminal:"
  info "  psql postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME"
  echo
  info "Logs:  kubectl -n $NS logs statefulset/$APP -f"
  info "Stop:  ./setup.sh down"
  print_summary
}

# ---------- main ----------
case "$MODE" in
  docker)
    bootstrap_base
    locate_repo
    run_docker
    ;;
  k8s)
    bootstrap_base
    locate_repo
    run_k8s
    ;;
  down)
    if [ -f "$0" ]; then cd "$(dirname "$0")"; fi
    do_down
    ;;
  *) echo "Usage: ./setup.sh [docker|k8s|down]" >&2; exit 1 ;;
esac
