CREATE KEYSPACE IF NOT EXISTS demo
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE demo;

CREATE TABLE IF NOT EXISTS cancellation_codes (
  cancellation_reason      text PRIMARY KEY,
  cancellation_description text
);

TRUNCATE cancellation_codes;

COPY cancellation_codes (cancellation_reason, cancellation_description)
FROM '/tmp/cancellation_codes.csv'
WITH HEADER = TRUE
AND DELIMITER = ',';
