# Presto Polyglot Demo (MySQL + MongoDB + Cassandra)

This project demonstrates a **PrestoDB federated query engine** working across **three completely different databases**:

- **MySQL** – relational OLTP-style tables  
- **MongoDB** – document store  
- **Cassandra** – wide-column NoSQL  
- **PrestoDB** – executes SQL queries joining all three

The dataset is **not included** in this repository (too large).  
Instead, download it manually from:

 **https://mavenanalytics.io/data-playground/airline-flight-delays**

Extract the ZIP archive and place these four CSV files into the `data/` directory:

- `airlines.csv`
- `airports.csv`
- `cancellation_codes.csv`
- `flights.csv`


It also includes **full automation scripts** to load all four CSV datasets, and a **manual fallback procedure** for each database if the scripts fail.

---


#  IMPORTANT FOR WINDOWS USERS: WSL2 REQUIRED

This project uses **Bash scripts (`.sh`)** for automated data loading.

###  These scripts do NOT work on:
- Windows PowerShell  
- Windows CMD  

###  You MUST use **WSL2 (Ubuntu or Debian)** on Windows  
Otherwise automation will fail.

Open your project via WSL:

```bash
cd /mnt/c/Users/<your_name>/presto-demo
./scripts/init-all.sh
```

If you cannot use WSL, follow the manual data loading instructions later in the README.

---
# Fix Script Permissions (Linux/macOS/WSL2)

If you see permission denied when running a script, simply run:

```bash
chmod +x scripts/*.sh
```


Or individually:
```bash
chmod +x scripts/init-all.sh
chmod +x scripts/init-mongodb.sh
```

Then execute normally:
```bash
./scripts/init-all.sh
```

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
└─ script/
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
./script/init-all.sh
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

# 7. Basic Presto Demo Queries

## 7.1 Catalog checks

```sql
SHOW CATALOGS;
SHOW SCHEMAS FROM mysql;
SHOW SCHEMAS FROM mongodb;
SHOW SCHEMAS FROM cassandra;
```

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

# 8. Additional Demo Queries (Full Set)

## 8.1 MySQL-only analytical queries

### Top 10 airlines by number of flights
```sql
SELECT a.AIRLINE, COUNT(*) nb_flights
FROM mysql.demo.flights f
JOIN mysql.demo.airlines a ON f.AIRLINE = a.IATA_CODE
GROUP BY a.AIRLINE
ORDER BY nb_flights DESC
LIMIT 10;
```

### Distance average by day
```sql
SELECT DAY, AVG(DISTANCE) AS avg_distance
FROM mysql.demo.flights
GROUP BY DAY
ORDER BY DAY;
```

---

## 8.2 MySQL + MongoDB (federated SQL + NoSQL)

### Delay average per origin city
```sql
SELECT ap.CITY, AVG(f.ARRIVAL_DELAY) avg_delay
FROM mysql.demo.flights f
JOIN mongodb.demo.airports ap ON f.ORIGIN_AIRPORT = ap.IATA_CODE
WHERE f.ARRIVAL_DELAY IS NOT NULL
GROUP BY ap.CITY
ORDER BY avg_delay DESC
LIMIT 20;
```

### Distance average per city
```sql
SELECT ap.CITY, AVG(f.DISTANCE) avg_distance
FROM mysql.demo.flights f
JOIN mongodb.demo.airports ap ON f.ORIGIN_AIRPORT = ap.IATA_CODE
GROUP BY ap.CITY
ORDER BY avg_distance DESC
LIMIT 20;
```

---

## 8.3 MySQL + Cassandra (federated SQL + wide-column NoSQL)

### Cancellation % per airline
```sql
SELECT a.AIRLINE,
       ROUND(100.0 * SUM(f.CANCELLED) / COUNT(*), 2) AS cancellation_rate
FROM mysql.demo.flights f
JOIN mysql.demo.airlines a ON f.AIRLINE = a.IATA_CODE
GROUP BY a.AIRLINE
ORDER BY cancellation_rate DESC;
```

### Cancellation reasons by hour
```sql
SELECT floor(f.SCHEDULED_DEPARTURE / 100) AS departure_hour,
       cc.cancellation_description,
       COUNT(*) AS nb
FROM mysql.demo.flights f
JOIN cassandra.demo.cancellation_codes cc ON f.CANCELLATION_REASON = cc.cancellation_reason
WHERE f.CANCELLED = 1
GROUP BY 1, cc.cancellation_description
ORDER BY 1, nb DESC;
```

---

## 8.4 Joins across ALL THREE databases (MySQL + MongoDB + Cassandra)

### The “Wow” query
```sql
SELECT
  ap.CITY,
  a.AIRLINE,
  cc.cancellation_description,
  COUNT(*) AS nb_flights,
  AVG(f.ARRIVAL_DELAY) AS avg_delay
FROM mysql.demo.flights f
LEFT JOIN mongodb.demo.airports ap
    ON f.ORIGIN_AIRPORT = ap.IATA_CODE
LEFT JOIN mysql.demo.airlines a
    ON f.AIRLINE = a.IATA_CODE
LEFT JOIN cassandra.demo.cancellation_codes cc
    ON f.CANCELLATION_REASON = cc.cancellation_reason
GROUP BY ap.CITY, a.AIRLINE, cc.cancellation_description
ORDER BY nb_flights DESC
LIMIT 20;
```

---

## 8.5 Fun queries

### Flights arriving early
```sql
SELECT COUNT(*) AS arrived_early
FROM mysql.demo.flights
WHERE ARRIVAL_DELAY < 0;
```

### Cities with most weather delay
```sql
SELECT ap.CITY, SUM(f.WEATHER_DELAY) AS total_weather_delay
FROM mysql.demo.flights f
JOIN mongodb.demo.airports ap ON f.ORIGIN_AIRPORT = ap.IATA_CODE
GROUP_BY ap.CITY
ORDER BY total_weather_delay DESC
LIMIT 10;
```

### Airline flying the longest distances
```sql
SELECT a.AIRLINE, AVG(f.DISTANCE) avg_dist
FROM mysql.demo.flights f
JOIN mysql.demo.airlines a ON f.AIRLINE = a.IATA_CODE
GROUP BY a.AIRLINE
ORDER BY avg_dist DESC;
```

# 8. Stopping and Cleaning Up

Stop everything:

```bash
docker-compose down
```

Stop + remove all volumes (wipe data):

```bash
docker-compose down -v
```


