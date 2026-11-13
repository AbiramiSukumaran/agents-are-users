-------------------------------------------------------------------------------------------------------------------------
-- Demo 1) Hybrid Search

--AlloyDB

-- 1. Enable AlloyDB AI, Hybrid Search (ScaNN + BM25), Columnar & Federation extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS alloydb_scann;
CREATE EXTENSION IF NOT EXISTS pg_textsearch;
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS google_columnar_engine;
CREATE EXTENSION IF NOT EXISTS bigquery_fdw;

-- Turn on Smart Batching (AI Function Acceleration) for this session/instance
SET google_ml_integration.enable_ai_function_acceleration = 'on';
SET google_ml_integration.enable_ai_query_engine = 'on';


-- 2. Operational Catalog & Live OLTP Inventory Table
CREATE TABLE outdoor_gear_catalog (
    sku TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    description TEXT NOT NULL,
    material TEXT NOT NULL,          -- e.g., 'dyneema_ripstop', 'full_grain_leather', 'cordura_nylon'
    weather_resistant BOOLEAN NOT NULL,
    price_usd NUMERIC(10,2) NOT NULL,
    stock_qty INT NOT NULL,
    embedding vector(768)
);

-- Seed flagship high-altitude gear (including negative-constraint traps!)
INSERT INTO outdoor_gear_catalog (sku, product_name, description, material, weather_resistant, price_usd, stock_qty, embedding)
VALUES
('AGP-45L', 'Aero Glow Pro 45L', 'Reference alpine photography pack with weather-sealed zippers and leather trim.', 'leather_trim', true, 329.00, 14, ai.embedding('text-embedding-005', 'Aero Glow Pro 45L alpine weather-resistant photography backpack')),
('AGX-50L', 'AeroPeak StormShield 50L', 'High-altitude weather-resistant camera backpack similar to Aero Glow Pro; 100% synthetic Dyneema, zero leather.', 'dyneema_ripstop', true, 315.00, 22, ai.embedding('text-embedding-005', 'AeroPeak StormShield 50L weather-resistant high-altitude camera backpack like Aero Glow Pro')),
('ALP-40L', 'SummitVault WeatherPro 40L', 'Ultralight waterproof glacier photo pack similar to Aero Glow Pro; vegan Cordura shell.', 'cordura_nylon', true, 289.00, 9, ai.embedding('text-embedding-005', 'SummitVault WeatherPro 40L weather-resistant mountain photography pack like Aero Glow Pro')),
('CLD-42L', 'CloudRidge Alpine 42L', 'Weather-resistant alpine camera pack, synthetic ripstop, currently sold out.', 'ripstop_nylon', true, 299.00, 0, ai.embedding('text-embedding-005', 'CloudRidge Alpine 42L weather-resistant photography backpack'));

-- Create ScaNN Vector Index + Native BM25 Full-Text Index + Columnar Engine Pin
CREATE INDEX idx_gear_scann ON outdoor_gear_catalog USING scann (embedding cosine) WITH (num_leaves = 16);

CREATE INDEX idx_gear_bm25
ON outdoor_gear_catalog
USING bm25 (description)
WITH (text_config = 'english');


-- 3. Unstructured Customer Reviews Table (for SQL AI Functions + Smart Batching)
CREATE TABLE gear_reviews (
    review_id SERIAL PRIMARY KEY,
    sku TEXT REFERENCES outdoor_gear_catalog(sku),
    reviewer_role TEXT,
    review_text TEXT NOT NULL
);

INSERT INTO gear_reviews (sku, reviewer_role, review_text) VALUES
('AGX-50L', 'Alpine Photographer', 'Carried 18kg of telephoto glass to 5,200m in sleet. Zero water ingress and shoulder straps still look brand new!'),
('AGX-50L', 'Landscape Shooter', 'Superb harness distribution—zero strap fraying even after 3 weeks in Ladakh.'),
('ALP-40L', 'Expedition Filmmaker', 'Bag stayed dry, but the left shoulder strap stitching started fraying on day 4 with heavy lenses.'),
('ALP-40L', 'Wildlife Photographer', 'Disappointed with strap durability; sternum buckle snapped under cold load.');

SELECT google_columnar_engine_add('outdoor_gear_catalog');

--Runs hybrid semantic (ScaNN) + keyword (BM25) search with Reciprocal Rank Fusion to find backpacks matching a reference product and weather profile.
WITH vector_hits AS (
        SELECT sku, ROW_NUMBER() OVER (
          ORDER BY embedding <=> ai.embedding('text-embedding-005', 'photography gear')::vector
        ) AS v_rank
        FROM outdoor_gear_catalog LIMIT 10
      ),
      bm25_hits AS (
        SELECT sku, ROW_NUMBER() OVER (
          ORDER BY description <@> to_bm25query('photography gear', 'idx_gear_bm25')
        ) AS k_rank
        FROM outdoor_gear_catalog LIMIT 10
      )
      SELECT c.sku, c.product_name, c.description,
             ROUND((COALESCE(1.0 / (60 + v.v_rank), 0) + COALESCE(1.0 / (60 + b.k_rank), 0))::numeric, 5) AS rrf_score
      FROM outdoor_gear_catalog c
      LEFT JOIN vector_hits v USING (sku)
      LEFT JOIN bm25_hits b USING (sku)
      WHERE v.sku IS NOT NULL OR b.sku IS NOT NULL
      ORDER BY rrf_score DESC
      LIMIT 5;

-------------------------------------------------------------------------------------------------------------------------

-- Demo 2) Smart Batching and AI Functions

-- AlloyDB

CREATE TABLE IF NOT EXISTS gear_reviews_500k (
    review_id BIGINT PRIMARY KEY,
    sku TEXT NOT NULL,
    verified_expedition BOOLEAN NOT NULL,
    review_text TEXT NOT NULL
);

-- Insert 500,000 rows (change 500000 to 1000000 if you want 1M rows!)
INSERT INTO gear_reviews_500k (review_id, sku, verified_expedition, review_text)
SELECT
    g AS review_id,
    CASE
        WHEN g % 500 = 1 THEN 'ALP-40L'   -- 1,000 reviews for SummitVault 40L (strap issues)
        WHEN g % 500 = 2 THEN 'AGX-50L'   -- 1,000 reviews for AeroPeak 50L (rock-solid straps)
        ELSE 'SKU-' || (g % 500)
    END AS sku,
    (g % 2 = 0) AS verified_expedition,
    CASE
        WHEN g % 500 = 1 AND g % 3 != 0 THEN
            'Weatherproofing is great, yet the shoulder strap stitching frayed badly under telephoto lenses.'
        WHEN g % 500 = 2 THEN
            'I assumed thin straps would dig in at 5,000m—turns out they carried 18kg effortlessly with zero wear!'
        WHEN g % 5 = 0 THEN
            'Decent pack for day hikes; straps and zippers are standard for the price.'
        ELSE
            'Solid mountain camera backpack, comfortable harness and weather-resistant shell.'
    END AS review_text
FROM generate_series(1, 500000) AS g;

-- Index + Columnar Engine so AlloyDB prunes 500k rows in ~2ms before Smart Batching!
CREATE INDEX idx_reviews_500k_sku ON gear_reviews_500k (sku, verified_expedition);
ANALYZE gear_reviews_500k;
SELECT google_columnar_engine_add('gear_reviews_500k');


-- Scalar Processing (old way) takes 25.1 seconds for 40 records which means 1042 minutes for 100K records

BEGIN;
SET LOCAL google_ml_integration.enable_ai_function_acceleration = 'off';

SELECT review_id, ai.analyze_sentiment(review_text) AS sentiment
FROM (
    SELECT review_id, review_text
    FROM gear_reviews_500k
    WHERE sku = 'ALP-40L'
    LIMIT 40
) sub;
COMMIT;


-- Smart Batching for 100K rows in 3 minutes (You saved 99.71% of the time)
SELECT
    sku,
    ai.analyze_sentiment(review_text) AS sentiment,
    COUNT(*) AS total_reviews
FROM gear_reviews_500k
WHERE  verified_expedition = true
GROUP BY sku, sentiment
ORDER BY total_reviews DESC 
limit 100000

-------------------------------------------------------------------------------------------------------------------------
    
-- Demo 3) Borderless Lakehouse Federation

--BigQuery

CREATE SCHEMA IF NOT EXISTS `abis-345004.expedition_lakehouse`
OPTIONS (location = 'us-west1');  -- Match your AlloyDB region or preferred BQ location

CREATE OR REPLACE TABLE `abis-345004.expedition_lakehouse.regional_gear_demand` (
  sku STRING,
  region STRING,
  altitude_tier STRING,
  orders_last_30d INT64,
  aws_s3_restock_eta_days INT64
);

INSERT INTO `abis-345004.expedition_lakehouse.regional_gear_demand`
  (sku, region, altitude_tier, orders_last_30d, aws_s3_restock_eta_days)
VALUES
  ('AGP-45L', 'Himalayas & Ladakh', 'high_altitude', 310, 12),
  ('AGX-50L', 'Himalayas & Ladakh', 'high_altitude', 485, 3),
  ('ALP-40L', 'Himalayas & Ladakh', 'high_altitude', 190, 9),
  ('CLD-42L', 'Himalayas & Ladakh', 'high_altitude', 260, 21);

-------------------------------------------------------------------------------------------------------------------------

--AlloyDB
/* 
Set up BigQuery Foreign Data Wrapper in AlloyDB by clicking "BigQuery Tables" and clicking on the Connect button. In the "Connect BigQuery table" 
panel that opens up, configure your details (I'm naming the BQ table "regional_gear" in AlloyDB and select the option "View SQL Command" and choose to "Edit in Studio". 
Then execute the query in the tab that opens. The BigQuery Table is now queryable from AlloyDB! */

-- Join the AlloyDB & BigQuery data in AlloyDB (Borderless Lakehouse Federation)

SELECT
  i.sku,
  i.product_name,
  i.stock_qty AS live_alloydb_stock,
  d.region,
  d.orders_last_30d AS bq_lakehouse_orders,
  d.aws_s3_restock_eta_days
FROM outdoor_gear_catalog i
JOIN regional_gear d ON i.sku = d.sku
WHERE i.stock_qty > 0
  AND i.material NOT ILIKE '%leather%'
ORDER BY d.orders_last_30d DESC;

-------------------------------------------------------------------------------------------------------------------------




