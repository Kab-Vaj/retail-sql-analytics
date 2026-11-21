#!/usr/bin/env bash
# Builds the analytics models, then runs every data test.
# Exits with status 1 if any test fails, so it can run in CI.
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${DB:-retail_portfolio}
export PGOPTIONS="--client-min-messages=warning"   # hide routine NOTICE messages
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f models/analytics_models.sql
psql -v ON_ERROR_STOP=1 -d "$DB" -f tests/data_tests.sql | tee /tmp/test_results.txt
if grep -q "FAIL" /tmp/test_results.txt; then
  echo "Some data tests FAILED." >&2
  exit 1
fi
echo "All data tests passed."
