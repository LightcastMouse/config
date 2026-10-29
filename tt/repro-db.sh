#!/bin/sh
# Data-only seed snapshot/restore of a worktree's real Postgres, for rerunning repros without `bun dump`/`bun db`.
# One shared file for every worktree; the schema is untouched and connections stay open, so a running dev server keeps working.
# Tables in $KEEP (login sessions) are left alone, so a reset does not log anyone out.
#   repro-db.sh snapshot   save the current data (do this right after a fresh `bun db`)
#   repro-db.sh reset      replace all seed data with the snapshot
# The snapshot is data-only, so it only fits a schema with the same tables/columns it was taken from: retake it after a migration changes them.
set -eu
KEEP="sessions"
[ -f .env ] || { echo "run from a worktree root with a .env" >&2; exit 2; }
url=$(sed -n 's/^DB_CONNECTION_STRING=//p' .env | tr -d '"')
[ -n "$url" ] || { echo "no DB_CONNECTION_STRING in .env (real Postgres only)" >&2; exit 2; }
mkdir -p "$HOME/.cache/repro-db"
snap="${REPRO_DB_SNAPSHOT:-$HOME/.cache/repro-db/seed.sql}"
keep_sql=$(for t in $KEEP; do printf "'%s'," "$t"; done | sed 's/,$//')

case "${1:-}" in
  snapshot)
    excludes=$(for t in $KEEP; do printf -- "--exclude-table-data=%s " "$t"; done)
    # shellcheck disable=SC2086
    pg_dump --data-only --no-owner --no-privileges $excludes "$url" > "$snap" 2>/dev/null
    echo "saved $snap ($(wc -c < "$snap" | tr -d ' ') bytes), without: $KEEP"
    ;;
  reset)
    [ -f "$snap" ] || { echo "no $snap: run 'repro-db snapshot' first" >&2; exit 2; }
    # One transaction. The replica role skips FK checks and triggers (e.g. updated_at) while reloading; DELETE rather than
    # TRUNCATE because TRUNCATE would cascade into the kept tables.
    {
      echo "BEGIN; SET client_min_messages = warning; SET session_replication_role = replica;"
      echo "DO \$\$ DECLARE t text; BEGIN"
      echo "  FOR t IN SELECT format('%I.%I', schemaname, tablename) FROM pg_tables"
      echo "    WHERE schemaname NOT IN ('pg_catalog','information_schema') AND tablename NOT IN ($keep_sql) LOOP"
      echo "    EXECUTE 'DELETE FROM ' || t; END LOOP; END \$\$;"
      cat "$snap"
      echo "COMMIT;"
    } | psql "$url" -v ON_ERROR_STOP=1 -q -o /dev/null
    echo "reset from $snap (kept: $KEEP)"
    ;;
  *) echo "usage: repro-db.sh snapshot|reset" >&2; exit 2 ;;
esac
