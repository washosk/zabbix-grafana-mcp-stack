#!/bin/sh
set -e

# This script runs on the first initialization of the PostgreSQL container.
# It creates a read-only user for the Grafana PostgreSQL datasource.

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${GRAFANA_RO_PASSWORD:?GRAFANA_RO_PASSWORD is required}"

export PGPASSWORD="$POSTGRES_PASSWORD"

echo "Creating read-only user 'grafana_ro'..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER grafana_ro WITH PASSWORD '${GRAFANA_RO_PASSWORD}';
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO grafana_ro;
    GRANT USAGE ON SCHEMA public TO grafana_ro;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana_ro;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana_ro;
EOSQL

echo "init-grafana.sh (ro-user only) completed."
