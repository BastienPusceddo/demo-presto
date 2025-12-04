#!/usr/bin/env bash
set -e

DATA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../data" && pwd)"

echo "[MongoDB] Copying airports.csv into container..."
docker cp "$DATA_DIR/airports.csv" mongodb:/tmp/airports.csv

echo "[MongoDB] Importing airports into demo.airports..."
docker exec -it mongodb mongoimport \
  --type csv \
  --headerline \
  --db demo \
  --collection airports \
  /tmp/airports.csv

echo "[MongoDB] Done."
