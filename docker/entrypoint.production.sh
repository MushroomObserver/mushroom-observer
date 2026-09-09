#!/bin/bash
set -e

# Always use the Docker database.yml (TCP) -- matches
# docker/entrypoint.sh's dev/test convention, extended to production.
cp db/docker/database.yml config/database.yml

# Only the server role prepares the database and precompiles assets. A
# second role sharing this same image with a different start command
# (e.g. `bin/jobs` for Solid Queue, matching
# config/etc/solidqueue.service) must not race either -- see #5345.
if [ "${1}" = "bin/rails" ] && [ "${2}" = "server" ]; then
  # Wait for the database to be reachable -- matches
  # docker/entrypoint.sh's dev/test wait loop.
  DB_HOST="${DATABASE_HOST:-db}"
  echo "Waiting for database at ${DB_HOST}:3306..."
  until </dev/tcp/"${DB_HOST}"/3306 2>/dev/null; do
    sleep 1
  done
  echo "Database is ready."

  bin/rails db:prepare

  # Assets can't precompile at build time -- see the Dockerfile's
  # comment on this same point. The real RAILS_MASTER_KEY (unlike at
  # build time) is available now, so no SECRET_KEY_BASE_DUMMY needed.
  # Skip if a previous container start (a shared volume, or this same
  # image re-run) already did it.
  if [ ! -d public/assets ]; then
    bin/rails assets:precompile
  fi
fi

exec "$@"
