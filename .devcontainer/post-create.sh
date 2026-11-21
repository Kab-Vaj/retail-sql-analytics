#!/usr/bin/env bash
# Runs once when the Codespace is created: installs the psql client,
# waits for the database to start, then loads data, builds models and runs tests.
set -euo pipefail
echo "Installing the PostgreSQL client..."
sudo apt-get update -qq && sudo apt-get install -y -qq postgresql-client > /dev/null

echo "Waiting for the database to start..."
for i in $(seq 1 30); do
  pg_isready -q && break
  sleep 2
done

./scripts/setup.sh
./scripts/run_tests.sh
echo
echo "Setup complete. Open GETTING_STARTED.md for what to do next."
