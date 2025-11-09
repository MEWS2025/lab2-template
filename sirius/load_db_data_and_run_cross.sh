#!/usr/bin/env bash
set -euo pipefail

# load_and_run.sh
# Usage:
#   ./load_and_run.sh [optional-path-to-seed.tar.gz]
#
# Behavior:
#   - If an argument is provided, uses that .tar.gz as the seed bundle.
#   - If no argument, uses ./sirius-db-seed.tar.gz
#   - Extracts to ./sirius-db-seed/init
#   - Starts postgres:<PG_MAJOR>, waits until ready, then runs the Spring Boot JAR.

# --- CONFIG (edit as needed) ---
CONTAINER_NAME="sirius-web-postgres"
PG_MAJOR="17"
PG_IMAGE="postgres:${PG_MAJOR}"
PORT="5433"
DB_USER="dbuser"
DB_PASS="dbpwd"
DB_NAME="sirius-web-db"
JAR_FILE="sirius-web.jar"
TARGET_DIR="sirius-db-seed"              # fixed extract folder name
DEFAULT_TAR="sirius-db-seed.tar.gz"
# --------------------------------

# --- Preconditions ---
command -v docker >/dev/null || { echo "❌ docker not found"; exit 1; }
command -v tar >/dev/null || { echo "❌ tar not found"; exit 1; }
[ -f "$JAR_FILE" ] || { echo "❌ JAR '$JAR_FILE' not found in $(pwd)"; exit 1; }

# --- Choose bundle ---
if [ $# -gt 0 ]; then
  BUNDLE_TAR="$1"
else
  BUNDLE_TAR="$DEFAULT_TAR"
fi
[ -f "$BUNDLE_TAR" ] || { echo "❌ Seed tar not found: $BUNDLE_TAR"; exit 1; }
echo "📦 Using seed bundle: $BUNDLE_TAR"

# --- Clean and extract ---
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
echo "📂 Extracting into ./${TARGET_DIR}/ ..."
tar --strip-components=1 -xzf "$BUNDLE_TAR" -C "$TARGET_DIR"

INIT_DIR="$PWD/${TARGET_DIR}/init"
[ -d "$INIT_DIR" ] || { echo "❌ Missing init dir: $INIT_DIR"; exit 1; }

# --- Start seeded Postgres ---
echo "📥 Pulling $PG_IMAGE ..."
docker pull "$PG_IMAGE" >/dev/null

echo "🧹 Removing old container (if any) ..."
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "🚀 Starting Postgres on port $PORT ..."
docker run -p "${PORT}:5432" --rm --name "$CONTAINER_NAME" \
  -e POSTGRES_USER="$DB_USER" \
  -e POSTGRES_PASSWORD="$DB_PASS" \
  -e POSTGRES_DB="$DB_NAME" \
  -v "$INIT_DIR":/docker-entrypoint-initdb.d:ro \
  -d "$PG_IMAGE" >/dev/null

cleanup() {
  echo -e "\n🛑 Stopping Postgres container..."
  docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# --- Wait for readiness ---
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

# --- Run the Spring Boot app ---
echo "🚀 Launching $JAR_FILE ..."
exec java -jar "$JAR_FILE" \
  --spring.datasource.url="jdbc:postgresql://localhost:${PORT}/${DB_NAME}" \
  --spring.datasource.username="$DB_USER" \
  --spring.datasource.password="$DB_PASS"
