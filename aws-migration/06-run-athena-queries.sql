-- ============================================================
-- Amazon Athena Queries for Uber Data Analytics
-- Step 06: Verify and Query Tables
-- ============================================================
-- Prerequisites:
-- 1. Glue Data Catalog database 'uber_data_db' created
-- 2. All dimension and fact tables registered (via Crawler)
-- 3. Athena workgroup configured
-- ============================================================

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- 1. Show all tables in database
SHOW TABLES IN uber_data_db;

-- 2. Count rows in fact table
SELECT COUNT(*) as total_trips FROM uber_data_db.fact_table;

-- 3. Count rows in each dimension table
SELECT 'datetime_dim' as table_name, COUNT(*) as row_count FROM uber_data_db.datetime_dim
UNION ALL
SELECT 'passenger_count_dim', COUNT(*) FROM uber_data_db.passenger_count_dim
UNION ALL
SELECT 'trip_distance_dim', COUNT(*) FROM uber_data_db.trip_distance_dim
UNION ALL
SELECT 'rate_code_dim', COUNT(*) FROM uber_data_db.rate_code_dim
UNION ALL
SELECT 'pickup_location_dim', COUNT(*) FROM uber_data_db.pickup_location_dim
UNION ALL
SELECT 'dropoff_location_dim', COUNT(*) FROM uber_data_db.dropoff_location_dim
UNION ALL
SELECT 'payment_type_dim', COUNT(*) FROM uber_data_db.payment_type_dim
UNION ALL
SELECT 'fact_table', COUNT(*) FROM uber_data_db.fact_table;

-- ============================================================
-- ANALYTICS QUERIES
-- ============================================================

-- 4. Revenue by year and month (as described in pipeline)
SELECT
  d.pick_year,
  d.pick_month,
  COUNT(*) AS trips,
  ROUND(SUM(f.total_amount), 2) AS revenue
FROM uber_data_db.fact_table f
JOIN uber_data_db.datetime_dim d
  ON f.datetime_id = d.datetime_id
GROUP BY d.pick_year, d.pick_month
ORDER BY d.pick_year, d.pick_month;

-- 5. Total trips and revenue by payment type
SELECT 
    pay.payment_type_name,
    COUNT(*) as total_trips,
    ROUND(SUM(f.total_amount), 2) as total_revenue,
    ROUND(AVG(f.total_amount), 2) as avg_fare
FROM uber_data_db.fact_table f
JOIN uber_data_db.payment_type_dim pay ON f.payment_type_id = pay.payment_type_id
GROUP BY pay.payment_type_name
ORDER BY total_revenue DESC;

-- 6. Revenue by hour of day (pickup time)
SELECT 
    d.pick_hour,
    COUNT(*) as trips,
    ROUND(SUM(f.total_amount), 2) as revenue
FROM uber_data_db.fact_table f
JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
GROUP BY d.pick_hour
ORDER BY d.pick_hour;

-- 7. Average trip statistics by passenger count
SELECT 
    p.passenger_count,
    COUNT(*) as trips,
    ROUND(AVG(t.trip_distance), 2) as avg_distance,
    ROUND(AVG(f.total_amount), 2) as avg_fare,
    ROUND(AVG(f.tip_amount), 2) as avg_tip
FROM uber_data_db.fact_table f
JOIN uber_data_db.passenger_count_dim p ON f.passenger_count_id = p.passenger_count_id
JOIN uber_data_db.trip_distance_dim t ON f.trip_distance_id = t.trip_distance_id
GROUP BY p.passenger_count
ORDER BY p.passenger_count;

-- 8. Sample data from fact table
SELECT * FROM uber_data_db.fact_table LIMIT 10;

-- 9. Sample data from datetime dimension
SELECT * FROM uber_data_db.datetime_dim LIMIT 10;

