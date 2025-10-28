#!/bin/sh
set -e
echo "Restoring seed into ${POSTGRES_DB} ..."
pg_restore \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  --no-owner --no-privileges \
  /docker-entrypoint-initdb.d/15-seed.dump
echo "Restore complete."
