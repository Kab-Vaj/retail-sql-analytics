#!/usr/bin/env bash
# Creates the retail_portfolio database and loads the schema and seed data.
# Usage: ./scripts/setup.sh            (uses your default PostgreSQL user)
#        PGUSER=postgres ./scripts/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${DB:-retail_portfolio}
export PGOPTIONS="--client-min-messages=warning"   # hide routine NOTICE messages
createdb "$DB" 2>/dev/null || echo "Database $DB already exists, reloading it."
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f schema/01_create_tables.sql -f data/02_seed_data.sql
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f models/analytics_models.sql
psql -d "$DB" -c "SELECT COUNT(*) AS orders_loaded FROM retail.orders;"
