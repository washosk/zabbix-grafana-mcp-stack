#!/bin/sh
set -eu

DBHOST="${DBHOST:-postgres}"
DBPORT="${DBPORT:-5432}"
DBNAME="${DBNAME:-zabbix}"
DBUSER="${DBUSER:-zabbix}"
DBPASS="${DBPASS:?DBPASS is required}"
DBSCHEMA="${DBSCHEMA:-public}"
OUTDIR="${OUTDIR:-/backup}"

mkdir -p "$OUTDIR"
export PGPASSWORD="$DBPASS"

# High-volume tables: dump schema only, skip data.
# These hold raw metrics and events and can be tens of GB even on small installs.
SCHEMA_ONLY_TABLES="
acknowledges
alerts
auditlog
event_recovery
event_suppress
event_symptom
event_tag
events
history
history_bin
history_log
history_str
history_text
history_uint
problem
problem_tag
task
task_acknowledge
task_check_now
task_close_problem
task_remote_command
task_remote_command_result
trends
trends_uint
"

# Use ISO weekday (1=Mon … 7=Sun) for a 7-file rolling window.
day="$(date +%u)"
outfile="$OUTDIR/zbx_cfg_${day}.sql"

set -- \
  -h "$DBHOST" \
  -p "$DBPORT" \
  -U "$DBUSER" \
  -d "$DBNAME" \
  -n "$DBSCHEMA" \
  --format=plain

for table in $SCHEMA_ONLY_TABLES; do
  set -- "$@" --exclude-table-data="${DBSCHEMA}.${table}"
done

pg_dump "$@" > "$outfile"
gzip -f "$outfile"

echo "[$(date '+%F %T')] Backup complete: ${outfile}.gz"
