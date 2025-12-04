# Presto Polyglot Demo (MySQL + MongoDB + Cassandra)

This project demonstrates a **PrestoDB federated query engine** working across **three completely different databases**:

- **MySQL** – relational OLTP-style tables  
- **MongoDB** – document store  
- **Cassandra** – wide-column NoSQL  
- **PrestoDB** – executes SQL queries joining all three

It also includes **full automation scripts** to load all four CSV datasets, and a **manual fallback procedure** for each database if the scripts fail.

---

# 1. Project Structure

```
presto-demo/
├─ docker-compose.yml
├─ README.md
├─ data/
│  ├─ airlines.csv
│  ├─ airports.csv
│  ├─ cancellation_codes.csv
│  └─ flights.csv
├─ presto/
│  ├─ catalog/
│  │  ├─ mysql.properties
│  │  ├─ mongodb.properties
│  │  └─ cassandra.properties
│  ├─ coordinator/etc/...
│  ├─ worker1/etc/...
│  ├─ worker2/etc/...
│  └─ worker3/etc/...
└─ scripts/
   ├─ init-mysql.sql
   ├─ init-cassandra.cql
   ├─ init-mongodb.sh
   └─ init-all.sh
```

---

# 2. Requirements

- Docker & Docker Compose
- Git
- The four CSV files placed inside `./data`:
  - `airlines.csv`
  - `airports.csv`
  - `cancellation_codes.csv`
  - `flights.csv`

---

# 3. Start All Services

```bash
docker-compose up -d
```

This starts:

| Service           | Purpose                          | Port |
|------------------|----------------------------------|------|
| Presto Coordinator | Query engine front-end           | 8080 |
| Presto Workers     | Distributed execution            | —    |
| MySQL              | Relational database              | 3306 |
| MongoDB            | Document database                | 27017 |
| Cassandra          | Wide-column NoSQL                | 9042 |

Presto UI:  
 http://localhost:8080

---

# 4. Automated Data Initialization

One command loads *all four datasets* into the three systems:

```bash
./scripts/init-all.sh
```

This script:

###  MySQL  
- Creates `airlines` and `flights`  
- Handles dirty data safely (NULLIF + TRIM)  
- Loads both CSVs  

###  MongoDB  
- Creates `demo.airports`  
- Loads the `airports.csv` via `mongoimport`  

###  Cassandra  
- Creates keyspace `demo`  
- Creates table `cancellation_codes`  
- Loads CSV via `COPY`  

You can re-run this script anytime.

---

# 5. Manual Data Loading (Fallback Option)

If the automated script fails on your machine, use the procedures below.

---

## 5.1 Manual MySQL Setup

### 1. Copy CSVs into the MySQL container

```bash
docker cp data/airlines.csv mysql:/var/lib/mysql-files/airlines.csv
docker cp data/flights.csv  mysql:/var/lib/mysql-files/flights.csv
```

### 2. Enter MySQL shell

```bash
docker exec -it mysql mysql -uroot -proot demo
```

### 3. Create tables

```sql
CREATE TABLE IF NOT EXISTS airlines (
  IATA_CODE VARCHAR(10) NULL,
  AIRLINE   VARCHAR(255) NULL
);

CREATE TABLE IF NOT EXISTS flights (
  YEAR INT NULL,
  MONTH INT NULL,
  DAY INT NULL,
  DAY_OF_WEEK INT NULL,
  AIRLINE VARCHAR(10) NULL,
  FLIGHT_NUMBER INT NULL,
  TAIL_NUMBER VARCHAR(20) NULL,
  ORIGIN_AIRPORT VARCHAR(10) NULL,
  DESTINATION_AIRPORT VARCHAR(10) NULL,
  SCHEDULED_DEPARTURE INT NULL,
  DEPARTURE_TIME INT NULL,
  DEPARTURE_DELAY INT NULL,
  TAXI_OUT INT NULL,
  WHEELS_OFF INT NULL,
  SCHEDULED_TIME INT NULL,
  ELAPSED_TIME INT NULL,
  AIR_TIME INT NULL,
  DISTANCE INT NULL,
  WHEELS_ON INT NULL,
  TAXI_IN INT NULL,
  SCHEDULED_ARRIVAL INT NULL,
  ARRIVAL_TIME INT NULL,
  ARRIVAL_DELAY INT NULL,
  DIVERTED TINYINT NULL,
  CANCELLED TINYINT NULL,
  CANCELLATION_REASON VARCHAR(10) NULL,
  AIR_SYSTEM_DELAY INT NULL,
  SECURITY_DELAY INT NULL,
  AIRLINE_DELAY INT NULL,
  LATE_AIRCRAFT_DELAY INT NULL,
  WEATHER_DELAY INT NULL
);
```

### 4. Load data (safe with empty fields)

```sql
TRUNCATE TABLE airlines;
LOAD DATA INFILE '/var/lib/mysql-files/airlines.csv'
INTO TABLE airlines
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

TRUNCATE TABLE flights;
-- Loads all columns with NULLIF() mapping
SOURCE /scripts/init-mysql.sql;
```

---

## 5.2 Manual MongoDB Setup

### 1. Copy CSV

```bash
docker cp data/airports.csv mongodb:/tmp/airports.csv
```

### 2. Import

```bash
docker exec -it mongodb mongoimport \
  --type csv \
  --headerline \
  --db demo \
  --collection airports \
  /tmp/airports.csv
```

---

## 5.3 Manual Cassandra Setup

### 1. Copy CSV

```bash
docker cp data/cancellation_codes.csv cassandra:/tmp/cancellation_codes.csv
```

### 2. Enter cqlsh

```bash
docker exec -it cassandra cqlsh
```

### 3. Create keyspace + table

```sql
CREATE KEYSPACE IF NOT EXISTS demo
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE demo;

CREATE TABLE IF NOT EXISTS cancellation_codes (
  cancellation_reason text PRIMARY KEY,
  cancellation_description text
);
```

### 4. Load the CSV

```sql
COPY cancellation_codes (cancellation_reason, cancellation_description)
FROM '/tmp/cancellation_codes.csv'
WITH HEADER = TRUE
AND DELIMITER = ',';
```

---

# 6. Presto Catalog Configuration

All catalogs are stored in `presto/catalog/`.

### MySQL — `mysql.properties`
```properties
connector.name=mysql
connection-url=jdbc:mysql://mysql:3306
connection-user=root
connection-password=root
```

### MongoDB — `mongodb.properties`
```properties
connector.name=mongodb
mongodb.seeds=mongodb:27017
```

### Cassandra — `cassandra.properties`
```properties
connector.name=cassandra
cassandra.contact-points=cassandra
cassandra.load-policy.local.dc=datacenter1
```

---

# 7. Presto Demo Queries

Run these in the Presto UI.

---

## 7.1 Catalog checks

```sql
SHOW CATALOGS;
SHOW SCHEMAS FROM mysql;
SHOW SCHEMAS FROM mongodb;
SHOW SCHEMAS FROM cassandra;
```

---

## 7.2 MySQL: Average delay by airline

```sql
SELECT
  a.AIRLINE,
  a.IATA_CODE,
  AVG(f.ARRIVAL_DELAY) AS avg_delay,
  COUNT(*) AS nb_flights
FROM mysql.demo.flights f
JOIN mysql.demo.airlines a
  ON f.AIRLINE = a.IATA_CODE
WHERE f.CANCELLED = 0
GROUP BY a.AIRLINE, a.IATA_CODE
HAVING COUNT(*) > 100
ORDER BY avg_delay DESC
LIMIT 10;
```

---

## 7.3 MySQL + MongoDB: Busiest origin cities

```sql
SELECT
  ap.CITY,
  ap.STATE,
  COUNT(*) AS nb_departures
FROM mysql.demo.flights f
JOIN mongodb.demo.airports ap
  ON f.ORIGIN_AIRPORT = ap.IATA_CODE
GROUP BY ap.CITY, ap.STATE
ORDER BY nb_departures DESC
LIMIT 10;
```

---

## 7.4 MySQL + Cassandra: Cancelled flights by reason

```sql
SELECT
  cc.cancellation_description,
  COUNT(*) AS nb_cancelled
FROM mysql.demo.flights f
JOIN cassandra.demo.cancellation_codes cc
  ON f.CANCELLATION_REASON = cc.cancellation_reason
WHERE f.CANCELLED = 1
GROUP BY cc.cancellation_description
ORDER BY nb_cancelled DESC;
```

---

# 8. Stopping and Cleaning Up

Stop everything:

```bash
docker-compose down
```

Stop + remove all volumes (wipe data):

```bash
docker-compose down -v
```


