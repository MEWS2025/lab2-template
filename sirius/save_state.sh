#!/usr/bin/env bash
set -euo pipefail

# Creates a portable, timestamped seed bundle from a running Postgres container.
# Friends can use the matching "run_with_seed.sh/.cmd" to restore and launch.

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

# --- Restore script (Linux/macOS: auto-runs in /docker-entrypoint-initdb.d) ---
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

# --- Restore script (Windows container-friendly .cmd placed in init dir) ---
# Note: This file is for convenience when using Windows-based containers or copying files around.
# It won't auto-run inside the official Postgres Linux image, but is included for parity.
_tmp_cmd="${WORKDIR}/16-restore.cmd.tmp"
cat > "$_tmp_cmd" <<'EOF'
@echo off
setlocal
echo Restoring seed into %POSTGRES_DB% ...
pg_restore -U %POSTGRES_USER% -d %POSTGRES_DB% --no-owner --no-privileges /docker-entrypoint-initdb.d/15-seed.dump
if errorlevel 1 ( echo Restore failed! & exit /b 1 )
echo Restore complete.
endlocal
EOF
# Convert to CRLF so Windows doesn't sulk
sed -e 's/$/\r/' "$_tmp_cmd" > "${INIT_DIR}/16-restore.cmd"
rm -f "$_tmp_cmd"

# --- Run script for friends (Linux/macOS) ---
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

# --- Run script for friends (Windows .cmd) ---
_tmp_run_cmd="${WORKDIR}/run_with_seed.cmd.tmp"
cat > "$_tmp_run_cmd" <<'EOF'
@echo off
setlocal EnableExtensions
set "CONTAINER_NAME=sirius-web-postgres-seeded"
set "IMAGE=postgres:__PG_MAJOR__"
set "PORT=__PORT_FOR_FRIENDS__"
set "DB_USER=__DB_USER__"
set "DB_PASS=dbpwd"
set "DB_NAME=__DB_NAME__"
set "SCRIPT_DIR=%~dp0"
set "INIT_DIR=%SCRIPT_DIR%init"

echo Pulling %IMAGE% ...
docker pull %IMAGE%

docker rm -f %CONTAINER_NAME% 2>nul

echo Starting seeded Postgres on port %PORT% ...
docker run -p %PORT%:5432 --rm --name %CONTAINER_NAME% ^
 -e POSTGRES_USER=%DB_USER% -e POSTGRES_PASSWORD=%DB_PASS% -e POSTGRES_DB=%DB_NAME% ^
 -v "%INIT_DIR%":/docker-entrypoint-initdb.d:ro ^
 -d %IMAGE%

if errorlevel 1 ( echo [ERROR] docker run failed. & exit /b 1 )

echo Waiting for Postgres to become ready ...
:wait_pg
docker exec %CONTAINER_NAME% pg_isready -U %DB_USER% -d %DB_NAME% >nul 2>&1
if errorlevel 1 (
  timeout /t 1 >nul
  goto wait_pg
)
echo ✅ Postgres ready at jdbc:postgresql://localhost:%PORT%/%DB_NAME%
endlocal
EOF
# Fill template vars and CRLF
sed -e "s/__PG_MAJOR__/${PG_MAJOR}/g" \
    -e "s/__PORT_FOR_FRIENDS__/${PORT_FOR_FRIENDS}/g" \
    -e "s/__DB_USER__/${DB_USER}/g" \
    -e "s/__DB_NAME__/${DB_NAME}/g" "$_tmp_run_cmd" | sed -e 's/$/\r/' \
    > "${WORKDIR}/${BUNDLE_DIR}/run_with_seed.cmd"
rm -f "$_tmp_run_cmd"

# --- README ---
cat > "${WORKDIR}/${BUNDLE_DIR}/README.md" <<EOF
# ${BUNDLE_DIR}

Portable snapshot of Postgres ${PG_MAJOR} from container \`${CONTAINER_NAME}\`.

## Quick start

### Linux/macOS
\`\`\`bash
./run_with_seed.sh
\`\`\`

### Windows
\`\`\`bat
run_with_seed.cmd
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
