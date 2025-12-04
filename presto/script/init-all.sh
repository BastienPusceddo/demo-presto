#!/usr/bin/env bash
set -e

DATA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../data" && pwd)"

echo "==== MySQL: copying CSVs ===="
docker cp "$DATA_DIR/airlines.csv" mysql:/var/lib/mysql-files/airlines.csv
docker cp "$DATA_DIR/flights.csv"  mysql:/var/lib/mysql-files/flights.csv

echo "==== MySQL: creating tables and loading data ===="
docker exec -i mysql mysql -uroot -proot demo < "$(dirname "$0")/init-mysql.sql"

echo "==== MongoDB: loading airports ===="
"$(dirname "$0")/init-mongodb.sh"

echo "==== Cassandra: copying CSV ===="
docker cp "$DATA_DIR/cancellation_codes.csv" cassandra:/tmp/cancellation_codes.csv

echo "==== Cassandra: creating keyspace/table and loading data ===="
docker exec -i cassandra cqlsh < "$(dirname "$0")/init-cassandra.cql"

echo "==== All data initialized! ===="
