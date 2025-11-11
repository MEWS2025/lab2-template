#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
CONTAINER_NAME="sirius-web-postgres"
DB_USER="dbuser"
DB_NAME="sirius-web-db"
PG_MAJOR="17"
BASENAME="sirius-db-seed"
# --------------------------------

command -v docker >/dev/null || { echo "docker not found"; exit 1; }

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BUNDLE="${BASENAME}-${TIMESTAMP}"
WORKDIR="$(mktemp -d 2>/dev/null || mktemp -d -t tmp)"
INIT_DIR="${WORKDIR}/${BUNDLE}/init"

echo "📦 Creating seed bundle: ${BUNDLE}"
mkdir -p "${INIT_DIR}"

# 1) Dump database
echo "🧪 Dumping DB from container '${CONTAINER_NAME}' ..."
docker exec -t "$CONTAINER_NAME" \
  pg_dump -U "$DB_USER" -d "$DB_NAME" -F c -f /tmp/seed.dump

# 2) Copy dump to host
docker exec "${CONTAINER_NAME}" \
  pg_dump -U "${DB_USER}" -d "${DB_NAME}" -F c > "${INIT_DIR}/seed.dump"


# 3) Create restore script for Linux/macOS (auto-runs in Postgres image)
cat > "${INIT_DIR}/restore.sh" <<'EOF'
#!/bin/sh
set -e
echo "Restoring database..."
pg_restore \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  --no-owner --no-privileges \
  /docker-entrypoint-initdb.d/seed.dump
echo "Restore complete."
EOF
chmod +x "${INIT_DIR}/restore.sh"

# 4) (Optional) Windows Git Bash users do NOT need .cmd; Docker Linux image ignores it anyway.

# 5) Package everything
OUTPUT="${PWD}/${BUNDLE}.tar.gz"
tar -C "${WORKDIR}" -czf "${OUTPUT}" "${BUNDLE}"

echo "✅ Seed created: ${OUTPUT}"
echo "🔐 SHA256: $(shasum -a 256 "${OUTPUT}" | awk '{print $1}')"
