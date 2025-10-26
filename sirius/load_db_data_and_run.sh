#!/usr/bin/env bash
set -euo pipefail

# use_db_seed_and_run_app.sh
# Usage:
#   ./use_db_seed_and_run_app.sh [optional-path-to-seed-tar.gz]
#
# Behavior:
#   1) If an argument is provided, uses that tar.gz as the seed bundle.
#   2) If no argument, auto-picks the latest timestamped bundle matching sirius-db-seed-*.tar.gz
#   3) Extracts it into ./sirius-db-seed/ (no timestamp in folder)
#   4) Starts seeded postgres:15, waits until ready, then runs sirius-web.jar.

# --- CONFIG ---
CONTAINER_NAME="sirius-web-postgres"
PG_IMAGE="postgres:17"
PORT="5433"
DB_USER="dbuser"
DB_PASS="dbpwd"
DB_NAME="sirius-web-db"
JAR_FILE="sirius-web.jar"
SEED_PATTERN="sirius-db-seed*.tar.gz"
TARGET_DIR="sirius-db-seed"  # fixed extract folder name
# --------------------------------

# --- Preconditions ---
command -v docker >/dev/null || { echo "❌ docker not found"; exit 1; }
[ -f "$JAR_FILE" ] || { echo "❌ JAR '$JAR_FILE' not found in $(pwd)"; exit 1; }

# --- Choose bundle ---
if [ $# -gt 0 ]; then
  BUNDLE_TAR="$1"
  [ -f "$BUNDLE_TAR" ] || { echo "❌ Provided tar not found: $BUNDLE_TAR"; exit 1; }
else
  BUNDLE_TAR="$(ls -t ${SEED_PATTERN} 2>/dev/null | head -1 || true)"
  if [ -z "${BUNDLE_TAR}" ]; then
    echo "❌ No tar provided and none found matching ${SEED_PATTERN} in $(pwd)"
    exit 1
  fi
fi
echo "📦 Using seed bundle: $BUNDLE_TAR"

# --- Clean old extraction if exists ---
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

# --- Extract tar (strip timestamped folder) ---
echo "📂 Extracting bundle into ./${TARGET_DIR}/ ..."
tar --strip-components=1 -xzf "$BUNDLE_TAR" -C "$TARGET_DIR"

INIT_DIR="$(pwd)/${TARGET_DIR}/init"
[ -d "$INIT_DIR" ] || { echo "❌ init folder missing in extracted bundle: $INIT_DIR"; exit 1; }

# --- Start seeded Postgres ---
echo "📥 Pulling image $PG_IMAGE ..."
docker pull "$PG_IMAGE" >/dev/null

echo "🧹 Removing old container $CONTAINER_NAME ..."
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "🚀 Starting Postgres (port $PORT) seeded from $INIT_DIR ..."
docker run -p ${PORT}:5432 --rm --name "$CONTAINER_NAME" \
  -e POSTGRES_USER="$DB_USER" \
  -e POSTGRES_PASSWORD="$DB_PASS" \
  -e POSTGRES_DB="$DB_NAME" \
  -v "$INIT_DIR":/docker-entrypoint-initdb.d:ro \
  -d "$PG_IMAGE" >/dev/null

cleanup() {
  echo ""
  echo "🛑 Stopping Postgres container..."
  docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# --- Wait for DB readiness ---
echo "⏳ Waiting for Postgres to be ready ..."
for i in {1..90}; do
  if docker exec "$CONTAINER_NAME" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 1
  if [ $i -eq 90 ]; then
    echo "❌ Postgres did not become ready in time."
    docker logs "$CONTAINER_NAME" || true
    exit 1
  fi
done
echo "✅ DB ready at jdbc:postgresql://localhost:${PORT}/${DB_NAME}"

# --- Run Java app ---
echo "🚀 Launching $JAR_FILE ..."
exec java -jar "$JAR_FILE" \
  --spring.datasource.url="jdbc:postgresql://localhost:${PORT}/${DB_NAME}" \
  --spring.datasource.username="$DB_USER" \
  --spring.datasource.password="$DB_PASS"
