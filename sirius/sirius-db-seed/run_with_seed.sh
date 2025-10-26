#!/usr/bin/env bash
set -e

CONTAINER_NAME="sirius-web-postgres-seeded"
IMAGE="postgres:17"
PORT="5433"
DB_USER="dbuser"
DB_PASS="dbpwd"
DB_NAME="sirius-web-db"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_DIR="${SCRIPT_DIR}/init"

echo "Pulling ${IMAGE}..."
docker pull "${IMAGE}"

docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

echo "Starting seeded Postgres on port ${PORT} ..."
docker run -p ${PORT}:5432 --rm --name "${CONTAINER_NAME}" \
  -e POSTGRES_USER="${DB_USER}" \
  -e POSTGRES_PASSWORD="${DB_PASS}" \
  -e POSTGRES_DB="${DB_NAME}" \
  -v "${INIT_DIR}":/docker-entrypoint-initdb.d:ro \
  -d "${IMAGE}"

echo "Waiting for Postgres..."
until docker exec "${CONTAINER_NAME}" pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; do
  sleep 1
done

echo "✅ Postgres ready at jdbc:postgresql://localhost:${PORT}/${DB_NAME}"
