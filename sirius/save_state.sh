#!/usr/bin/env bash
set -euo pipefail

# Creates a portable, timestamped seed bundle from a running Postgres container.
# Friends can use the matching "use_db_seed_and_run_app.sh" to restore and launch.

# --- CONFIG ---
CONTAINER_NAME="sirius-web-postgres"
DB_USER="dbuser"
DB_NAME="sirius-web-db"
PG_MAJOR="17"
PORT_FOR_FRIENDS="5433"
BUNDLE_BASENAME="sirius-db-seed"
# --------------------------------

# --- Timestamped output ---
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BUNDLE_DIR="${BUNDLE_BASENAME}-${TIMESTAMP}"
WORKDIR="$(mktemp -d)"
INIT_DIR="${WORKDIR}/${BUNDLE_DIR}/init"

echo "📦 Creating timestamped bundle: ${BUNDLE_DIR}"

# 1️⃣ Dump the live DB
echo "🧪 Dumping database from container '$CONTAINER_NAME'..."
docker exec -t "$CONTAINER_NAME" \
  pg_dump -U "$DB_USER" -d "$DB_NAME" -F c -f /tmp/seed.dump

# 2️⃣ Copy dump to host
docker cp "${CONTAINER_NAME}:/tmp/seed.dump" "${WORKDIR}/seed.dump"

# 3️⃣ Prepare bundle structure
mkdir -p "$INIT_DIR"

cp "${WORKDIR}/seed.dump" "${INIT_DIR}/15-seed.dump"

# --- Restore script (auto-runs in /docker-entrypoint-initdb.d) ---
cat > "${INIT_DIR}/16-restore.sh" <<'EOF'
#!/bin/sh
set -e
echo "Restoring seed into ${POSTGRES_DB} ..."
pg_restore \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  --no-owner --no-privileges \
  /docker-entrypoint-initdb.d/15-seed.dump
echo "Restore complete."
EOF
chmod +x "${INIT_DIR}/16-restore.sh"

# --- Run script for friends ---
cat > "${WORKDIR}/${BUNDLE_DIR}/run_with_seed.sh" <<EOF
#!/usr/bin/env bash
set -e

CONTAINER_NAME="sirius-web-postgres-seeded"
IMAGE="postgres:${PG_MAJOR}"
PORT="${PORT_FOR_FRIENDS}"
DB_USER="${DB_USER}"
DB_PASS="dbpwd"
DB_NAME="${DB_NAME}"

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
INIT_DIR="\${SCRIPT_DIR}/init"

echo "Pulling \${IMAGE}..."
docker pull "\${IMAGE}"

docker rm -f "\${CONTAINER_NAME}" 2>/dev/null || true

echo "Starting seeded Postgres on port \${PORT} ..."
docker run -p \${PORT}:5432 --rm --name "\${CONTAINER_NAME}" \\
  -e POSTGRES_USER="\${DB_USER}" \\
  -e POSTGRES_PASSWORD="\${DB_PASS}" \\
  -e POSTGRES_DB="\${DB_NAME}" \\
  -v "\${INIT_DIR}":/docker-entrypoint-initdb.d:ro \\
  -d "\${IMAGE}"

echo "Waiting for Postgres..."
until docker exec "\${CONTAINER_NAME}" pg_isready -U "\${DB_USER}" -d "\${DB_NAME}" >/dev/null 2>&1; do
  sleep 1
done

echo "✅ Postgres ready at jdbc:postgresql://localhost:\${PORT}/\${DB_NAME}"
EOF
chmod +x "${WORKDIR}/${BUNDLE_DIR}/run_with_seed.sh"

# --- README ---
cat > "${WORKDIR}/${BUNDLE_DIR}/README.md" <<EOF
# ${BUNDLE_DIR}

This archive contains a snapshot of Postgres ${PG_MAJOR} data from container \`${CONTAINER_NAME}\`.

## Quick start
\`\`\`bash
./run_with_seed.sh
\`\`\`

Postgres will listen on port ${PORT_FOR_FRIENDS}.
JDBC: \`jdbc:postgresql://localhost:${PORT_FOR_FRIENDS}/${DB_NAME}\`
User: \`${DB_USER}\`  Password: \`dbpwd\`
EOF

# 4️⃣ Package as tar.gz with timestamp
OUTPUT_TGZ="${PWD}/${BUNDLE_DIR}.tar.gz"
tar -C "${WORKDIR}" -czf "${OUTPUT_TGZ}" "${BUNDLE_DIR}"

# 5️⃣ Done
echo "✅ Seed bundle created: ${OUTPUT_TGZ}"
echo "🔐 SHA256: $(shasum -a 256 "${OUTPUT_TGZ}" | awk '{print $1}')"
