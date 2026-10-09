-- task 1.2 
CREATE TABLE zones (
    id TEXT,
    description TEXT
); -- from BZN.csv

-- once each table is created, we used the 'import/export' function of the tables 
-- to get access directly to the correspondent excel file 
CREATE TABLE cty_raw (
    id TEXT,
    description TEXT
); -- from CTY.csv

CREATE TABLE cty_bzn_raw (
    cty TEXT,
    bzn TEXT
); -- from CTY_BZN.csv

CREATE TABLE prices_raw (
    datetime TIMESTAMPTZ,
    price NUMERIC,
    bzn TEXT
); -- from day_ahead_electricity_market.csv

CREATE TABLE generation_raw (
    datetime TIMESTAMPTZ,
    generation NUMERIC,
    country TEXT,
    technology TEXT
); -- from actual_wind_solar_generation.csv

CREATE TABLE demand_raw (
    datetime TIMESTAMPTZ,
    load NUMERIC,
    country TEXT
); -- from actual_demand.csv


-- time coverage, measured by the minimum and maximum timestamps;
-- This query checks the period covered by the time-series tables.
-- It reports the first and last timestamp available in prices, demand,
-- and generation.

SELECT 'prices' AS table_name,
       min(datetime) AS start_time,
       max(datetime) AS end_time,
       count(*) AS rows
FROM prices_raw
UNION ALL
SELECT 'demand',
       min(datetime),
       max(datetime),
       count(*)
FROM demand_raw
UNION ALL
SELECT 'generation',
       min(datetime),
       max(datetime),
       count(*)
FROM generation_raw
ORDER BY table_name;

-- --------------------------------------------
-- TASK 2. DATABASE VERIFICATION AND CLEANING 
-- --------------------------------------------

-- -- 2.1: DATA VERIFICATION
-- -- This section checks the internal consistency of the imported tables.
-- -- looking at missing values, duplicated observations,
-- -- and implausible numerical values.

-- -- MISSING VALUES: 
-- Missing values in reference tables

SELECT 'countries' AS table_name,
       count(*) AS total_rows,
       count(*) FILTER (WHERE id IS NULL) AS missing_id,
       count(*) FILTER (WHERE description IS NULL) AS missing_description
FROM cty_raw
UNION ALL
SELECT 'bidding_zones',
       count(*),
       count(*) FILTER (WHERE id IS NULL),
       count(*) FILTER (WHERE description IS NULL)
FROM zones;
-- no missing values in reference tables

-- Missing values in correspondence table
SELECT 'cty_bzn' AS table_name,
       count(*) AS total_rows,
       count(*) FILTER (WHERE cty IS NULL) AS missing_country,
       count(*) FILTER (WHERE bzn IS NULL) AS missing_bidding_zone
FROM cty_bzn_raw;
-- no missing value in the correspondence table 

-- Missing values in time-series tables

SELECT 'prices' AS table,
       count(*) AS total_observations,
       count(*) FILTER (WHERE datetime IS NULL) AS missing_datetime,
       count(*) FILTER (WHERE price IS NULL) AS missing_value,
       count(*) FILTER (WHERE bzn IS NULL) AS missing_unit
FROM prices_raw
UNION ALL
SELECT 'demand',
       count(*),
       count(*) FILTER (WHERE datetime IS NULL),
       count(*) FILTER (WHERE load IS NULL),
       count(*) FILTER (WHERE country IS NULL)
FROM demand_raw
UNION ALL
SELECT 'generation',
       count(*),
       count(*) FILTER (WHERE datetime IS NULL),
       count(*) FILTER (WHERE generation IS NULL),
       count(*) FILTER (WHERE country IS NULL)
FROM generation_raw;
-- no missing values in time series data

-- Time frequency checks
-- This query counts the number of distinct timestamps and identifies
-- the minimum and maximum time interval between consecutive observations.

WITH price_times AS (
    SELECT DISTINCT datetime
    FROM prices_raw
),
demand_times AS (
    SELECT DISTINCT datetime
    FROM demand_raw
),
generation_times AS (
    SELECT DISTINCT datetime
    FROM generation_raw
),
price_gaps AS (
    SELECT datetime - lag(datetime) OVER (ORDER BY datetime) AS gap
    FROM price_times
),
demand_gaps AS (
    SELECT datetime - lag(datetime) OVER (ORDER BY datetime) AS gap
    FROM demand_times
),
generation_gaps AS (
    SELECT datetime - lag(datetime) OVER (ORDER BY datetime) AS gap
    FROM generation_times
)
SELECT 'prices' AS table_name,
       count(*) AS distinct_timestamps,
       min(gap) AS min_gap,
       max(gap) AS max_gap
FROM price_gaps
WHERE gap IS NOT NULL
UNION ALL
SELECT 'demand',
       count(*),
       min(gap),
       max(gap)
FROM demand_gaps
WHERE gap IS NOT NULL
UNION ALL
SELECT 'generation',
       count(*),
       min(gap),
       max(gap)
FROM generation_gaps
WHERE gap IS NOT NULL;
-- thoughtout this inspection, the prices' table 
-- is the only problematic one, with a maximum gap of 3h
-- instead of usual 15min

-- DUPLICATES
-- These queries verify whether the observational units are unique.

SELECT 'countries' AS table,
       count(*) AS duplicated_obs
FROM (
    SELECT id
    FROM cty_raw
    GROUP BY id
    HAVING count(*) > 1
) -- no duplicates
UNION ALL
SELECT 'bidding_zones',
       count(*)
FROM (
    SELECT id
    FROM zones
    GROUP BY id
    HAVING count(*) > 1
) -- no duplicates
UNION ALL
SELECT 'corr_cty_bzn',
       count(*)
FROM (
    SELECT cty, bzn
    FROM cty_bzn_raw
    GROUP BY cty, bzn
    HAVING count(*) > 1
) x -- no duplicates
UNION ALL
SELECT 'prices',
       count(*)
FROM (
    SELECT datetime, bzn
    FROM prices_raw
    GROUP BY datetime, bzn
    HAVING count(*) > 1
) -- 37533 duplicates
UNION ALL
SELECT 'demand',
       count(*)
FROM (
    SELECT datetime, country
    FROM demand_raw
    GROUP BY datetime, country
    HAVING count(*) > 1
) -- 186200 duplicates
UNION ALL
SELECT 'generation',
       count(*)
FROM (
    SELECT datetime, country, technology
    FROM generation_raw
    GROUP BY datetime, country, technology
    HAVING count(*) > 1
); -- 258 duplicates


-- Numerical range checks
-- This query checks minimum values, maximum values, and negative observations.

SELECT 'prices' AS table_name,
       min(price) AS min_value,
       max(price) AS max_value,
       count(*) FILTER (WHERE price < 0) AS negative_values -- 10200 found
FROM prices
UNION ALL
SELECT 'demand',
       min(load),
       max(load),
       count(*) FILTER (WHERE load < 0)
FROM demand
UNION ALL
SELECT 'generation',
       min(generation),
       max(generation),
       count(*) FILTER (WHERE generation < 0)
FROM generation;

-- Consistency between main tables and reference tables
-- This checks whether countries and bidding zones appearing in the data
-- are present in the reference tables.

SELECT 'demand_country_not_in_countries' AS check_name,
       count(DISTINCT d.country) AS problems
FROM demand_raw d
LEFT JOIN cty_raw c ON d.country = c.id
WHERE c.id IS NULL
UNION ALL
SELECT 'generation_country_not_in_countries',
       count(DISTINCT g.country)
FROM generation_raw g
LEFT JOIN cty_raw c ON g.country = c.id
WHERE c.id IS NULL
UNION ALL
SELECT 'prices_bzn_not_in_bidding_zones',
       count(DISTINCT p.bzn)
FROM prices_raw p
LEFT JOIN zones_raw z ON p.bzn = z.id
WHERE z.id IS NULL
UNION ALL
SELECT 'corr_country_not_in_countries',
       count(DISTINCT cb.cty)
FROM cty_bzn_raw cb
LEFT JOIN cty_raw c ON cb.cty = c.id
WHERE c.id IS NULL
UNION ALL
SELECT 'corr_bzn_not_in_bidding_zones',
       count(DISTINCT cb.bzn)
FROM cty_bzn_raw cb
LEFT JOIN zones_raw z ON cb.bzn = z.id
WHERE z.id IS NULL;
-- the only non-correspondence has been found in prices table 

-- inconsinstency between reference table and within different table 
SELECT * FROM zones_raw -- as DE-LU
SELECT * FROM cty_raw -- as DE and 'description' just 'Germany'
SELECT * FROM cty_bzn_raw -- here there are the two countries separated both as 'DE-LU'
SELECT * FROM prices_raw WHERE bzn = 'DE_LU' -- as 'DE_LU'
SELECT * FROM generation_raw WHERE country = 'DE' -- as DE
SELECT * FROM demand_raw WHERE country = 'DE' -- as DE

-- uniform under 'DE_LU' as in prices
UPDATE zones_raw SET id = 'DE_LU' WHERE id = 'DE-LU'
UPDATE cty_raw SET id = 'DE_LU' WHERE id = 'DE'
UPDATE cty_raw SET description = 'Germany / Luxembourg' WHERE description = 'Germany'
UPDATE cty_bzn_raw SET cty = 'DE_LU' WHERE cty = 'DE'
UPDATE cty_bzn_raw SET cty = 'DE_LU' WHERE cty = 'LU'
-- at this point in this table we will have two duplicated rows 
-- but they will be filtered later in the creation of the final tables 
-- throughout the DISTINCT 
UPDATE cty_bzn_raw SET bzn = 'DE_LU' WHERE bzn = 'DE-LU'
UPDATE generation_raw SET country = 'DE_LU' WHERE country = 'DE'
UPDATE demand_raw SET country = 'DE_LU' WHERE country = 'DE'

-- at this point, the relevant incosinstecy between tables referring 
-- to Germany and Luxembourg eletricty market have been removed 


-- 2.2 CLEANED TABLES 
-- cleaned prices 
CREATE TABLE prices AS
SELECT *
FROM (SELECT *,
           ROW_NUMBER() OVER (
            PARTITION BY datetime, bzn 
            ORDER BY datetime) AS rn
    FROM prices_raw) t
WHERE rn = 1 -- 869421

SELECT * FROM prices_raw -- 907533
-- 38112 deleted
-- despite having detected 37533 duplicates before 
-- now, the number of deleted observations is slightly larger (38112)
-- the query used to detect duplicates uses GROUP BY 
-- that therefore return us the number of GROUPS WITH DUPLICATES
-- while the query to delete the duplicates removes the duplicated rows 
-- which could not coincide with the number of duplicated groups because 
-- some groups may have more than one duplicated row 

-- to check this
SELECT n, COUNT(*) AS num_groups
FROM (
    SELECT COUNT(*) AS n
    FROM prices_raw
    GROUP BY datetime, bzn
) t
GROUP BY n
ORDER BY n;
-- The difference arises because duplicate groups and duplicate rows are different: 
-- the former counts groups with repeated keys, while the latter counts all redundant 
-- observations within each group.

-- cleaned demand 
CREATE TABLE demand AS SELECT *
FROM (SELECT *, ROW_NUMBER() OVER (
                PARTITION BY datetime, country
                ORDER BY datetime) AS rn
      FROM demand_raw) t
WHERE rn = 1;


-- 937348 remaining rows after having removed duplicated ones 
SELECT COUNT(*) from demand_raw -- 1123548

-- so the remaining rows are exactly the difference between 1123548 and 186200 
-- duplicated groups previously found 
-- this makes us think, unlike prices, that there are no groups of duplicated 
-- observations larger than 2
-- to check this 
SELECT n, COUNT(*) AS num_groups
FROM (
    SELECT COUNT(*) AS n
    FROM demand_raw
    GROUP BY datetime, country
) t
GROUP BY n
ORDER BY n;

-- cleaned generation
CREATE TABLE generation AS SELECT *
FROM (SELECT *, ROW_NUMBER() OVER (
                PARTITION BY datetime, country, technology
                ORDER BY datetime) AS rn
      FROM generation_raw) t
WHERE rn = 1; -- 1048317 remaining rows after having removed duplicated ones

SELECT * FROM generation_raw -- 1048575
-- From 1048575 observations we removed 258 ones to get 1048317
SELECT n, COUNT(*) AS num_groups
FROM (
    SELECT COUNT(*) AS n
    FROM generation_raw
    GROUP BY datetime, country, technology
) t
GROUP BY n
ORDER BY n;
-- this confirms that there were only 258 duplicated groups composed by two rows 
-- therefore, we need to eliminate exactly 258 rows

-- These tables did not contain missing values or duplicates,
-- so the cleaned versions are direct copies of the raw tables.

CREATE TABLE cty AS
SELECT DISTINCT *
FROM cty_raw;

CREATE TABLE zones AS
SELECT DISTINCT *
FROM zones_raw;

CREATE TABLE cty_bzn AS
SELECT DISTINCT *
FROM cty_bzn_raw;

-- task 3.2 - 3.3: CONSTRUCTION EMPIRICAL DATASETS

WITH 
-- 1. Daily aggregation of demand (country: DE_LU)
daily_demand AS (
    SELECT 
        DATE(datetime) AS obs_date,
        country,
        SUM(load) AS total_daily_load
    FROM demand
    WHERE country = 'DE_LU' 
      AND datetime >= '2022-01-01' 
      AND datetime < '2023-01-01'
    GROUP BY DATE(datetime), country
),
-- 2. Daily aggregation of renewable gneration (country: DE_LU)
daily_generation AS (
    SELECT 
        DATE(datetime) AS obs_date,
        country,
        SUM(generation) AS total_daily_ren_gen
    FROM generation
    WHERE country = 'DE_LU' 
      AND datetime >= '2022-01-01' 
      AND datetime < '2023-01-01'
    GROUP BY DATE(datetime), country
),
-- 3. Daily aggregation of prices (bidding zone: DE_LU)
daily_prices AS (
    SELECT 
        DATE(datetime) AS obs_date,
        bzn,
        AVG(price) AS avg_daily_price
    FROM prices
    WHERE bzn = 'DE_LU' 
      AND datetime >= '2022-01-01' 
      AND datetime < '2023-01-01'
    GROUP BY DATE(datetime), bzn
)
-- 4. Final JOIN and calculus of derivated variables (Task 3.2 and 3.3)
SELECT 
    d.obs_date,
    map.cty AS country_code,
    map.bzn AS bidding_zone,
    d.total_daily_load,
    g.total_daily_ren_gen,
    p.avg_daily_price,
    -- Derivated variable 1: Resisual load 
    (d.total_daily_load - g.total_daily_ren_gen) AS residual_load,
    -- Derivated Variable 2: Renewable Share (%)
    ROUND((g.total_daily_ren_gen / NULLIF(d.total_daily_load, 0) * 100)::NUMERIC, 2) AS ren_share_pct,
    -- Window Function: Moving Average of 7 days
    AVG(p.avg_daily_price) OVER (
        ORDER BY d.obs_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS price_7d_ma
FROM cty_bzn map
-- We unify the demand using the identifying national code (cty)
JOIN daily_demand d ON map.cty = d.country
-- We unify the generation using identifying national code and time
JOIN daily_generation g ON map.cty = g.country AND d.obs_date = g.obs_date
-- We unify prices using the bidding zone's code and the time 
JOIN daily_prices p ON map.bzn = p.bzn AND d.obs_date = p.obs_date
WHERE map.cty = 'DE_LU'
ORDER BY d.obs_date;

------- extension of the dataset by diving the renewable source
WITH 
daily_demand AS (
    SELECT DATE(datetime) AS obs_date, 
    country, 
    SUM(load) AS total_daily_load
    FROM demand
    WHERE country = 'DE_LU' 
      AND datetime >= '2022-01-01' 
      AND datetime < '2023-01-01'
    GROUP BY DATE(datetime), country
),
-- THE DIFFERENCE IS HERE: Split Wind and Solar
daily_generation_split AS (
    SELECT 
        DATE(datetime) AS obs_date,
        country,
        -- Sum only if the technology contains the word 'Wind' (Onshore or Offshore)
        SUM(CASE WHEN technology ILIKE '%wind%' THEN generation ELSE 0 END) AS wind_gen,
        -- Sum only if the technology contains the word 'Solar'
        SUM(CASE WHEN technology ILIKE '%solar%' THEN generation ELSE 0 END) AS solar_gen
    FROM generation
    WHERE country = 'DE_LU' AND datetime >= '2022-01-01' AND datetime < '2023-01-01'
    GROUP BY DATE(datetime), country
),
daily_prices AS (
    SELECT DATE(datetime) AS obs_date, 
    bzn, 
    AVG(price) AS avg_daily_price
    FROM prices
    WHERE bzn = 'DE_LU' AND datetime >= '2022-01-01' AND datetime < '2023-01-01'
    GROUP BY DATE(datetime), bzn
)
SELECT 
    d.obs_date,
    map.cty AS country_code,
    map.bzn AS bidding_zone,
    d.total_daily_load,
    g.wind_gen,       -- New column
    g.solar_gen,      -- New column
    p.avg_daily_price,
    (d.total_daily_load - (g.wind_gen + g.solar_gen)) AS residual_load,
    AVG(p.avg_daily_price) OVER (
        ORDER BY d.obs_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) 
    AS price_7d_ma
FROM cty_bzn map
JOIN daily_demand d ON map.cty = d.country
JOIN daily_generation_split g ON map.cty = g.country AND d.obs_date = g.obs_date
JOIN daily_prices p ON map.bzn = p.bzn AND d.obs_date = p.obs_date
WHERE map.cty = 'DE_LU'
ORDER BY d.obs_date;
