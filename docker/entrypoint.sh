#!/bin/bash
set -e

# Always use the Docker database.yml (TCP) when DATABASE_HOST is set,
# overwriting any socket-based config from a local dev environment.
if [ -n "${DATABASE_HOST:-}" ]; then
  cp db/docker/database.yml config/database.yml
fi

# Create config/master.key if absent (dev key matching vagrant default)
if [ ! -f config/master.key ]; then
  echo "5f343cfc11a623c470d23e25221972b5" > config/master.key
  echo "Created config/master.key"
fi

# Create required runtime directories
mkdir -p log public/images/thumb public/images/320 public/images/640 \
         public/images/960 public/images/1280 public/images/orig
touch log/development.log log/test.log log/production.log

# Populate bundle volume on first run
bundle check || bundle install

# Wait for the database to be reachable
DB_HOST="${DATABASE_HOST:-db}"
echo "Waiting for database at ${DB_HOST}:3306..."
until </dev/tcp/"${DB_HOST}"/3306 2>/dev/null; do
  sleep 1
done
echo "Database is ready."

# Create databases and run migrations (idempotent)
bin/rails db:prepare

# Write TCP-based mysql cnf files to MO_MYSQL_CONFIG_DIR (outside the
# bind-mounted app directory) so the tracked config/mysql-*.cnf files
# are never modified.
DB_USER="${DATABASE_USERNAME:-mo}"
DB_PASS="${DATABASE_PASSWORD:-mo}"
CNF_DIR="${MO_MYSQL_CONFIG_DIR:-/etc/mo-mysql}"
DB_NAME_DEV="${DATABASE_NAME:-mo_development}"
DB_NAME_TEST="${MO_TEST_DATABASE:-mo_test}"
mkdir -p "$CNF_DIR"

cat > "$CNF_DIR/mysql-development.cnf" <<EOF
[client]
host=${DB_HOST}
port=3306
user=${DB_USER}
password=${DB_PASS}

[mysql]
database=${DB_NAME_DEV}
EOF

cat > "$CNF_DIR/mysql-test.cnf" <<EOF
[client]
host=${DB_HOST}
port=3306
user=${DB_USER}
password=${DB_PASS}

[mysql]
database=${DB_NAME_TEST}
EOF

# Pre-create parallel worker cnf files in config/ (gitignored).
# ImageScriptTest writes these itself when absent, but only with default
# credentials. Pre-creating them here ensures Docker credentials are used
# and the test's "unless File.exist?" branch is never triggered.
WORKERS="${PARALLEL_WORKERS:-4}"
for i in $(seq 0 $((WORKERS - 1))); do
  cat > "config/mysql-test-${i}.cnf" <<EOF
[client]
host=${DB_HOST}
port=3306
user=${DB_USER}
password=${DB_PASS}

[mysql]
database=mo_test-${i}
EOF
done

exec "$@"
