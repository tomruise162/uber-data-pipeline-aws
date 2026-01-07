-- ============================================================
-- Business Metrics & KPIs for Uber Data
-- Step 11: Business Metrics Development
-- ============================================================
-- This file contains:
-- - Key Performance Indicators (KPIs)
-- - Business Metrics Views
-- - Performance Tracking Queries
-- ============================================================

-- ============================================================
-- 1. CREATE MATERIALIZED VIEWS FOR KPIs
-- ============================================================

-- 1.1 Daily KPI Summary View
CREATE OR REPLACE VIEW uber_data_db.vw_daily_kpis AS
SELECT 
    DATE(d.tpep_pickup_datetime) as metric_date,
    COUNT(*) as total_trips,
    COUNT(DISTINCT f.VendorID) as active_vendors,
    ROUND(SUM(f.total_amount), 2) as total_revenue,
    ROUND(AVG(f.total_amount), 2) as avg_trip_value,
    ROUND(SUM(f.tip_amount), 2) as total_tips,
    ROUND(AVG(f.tip_amount), 2) as avg_tip,
    ROUND(SUM(f.trip_distance), 2) as total_distance,
    ROUND(AVG(f.trip_distance), 2) as avg_distance,
    ROUND(
        SUM(f.tip_amount) / NULLIF(SUM(f.fare_amount), 0) * 100, 
        2
    ) as tip_percentage
FROM uber_data_db.fact_table f
JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
GROUP BY DATE(d.tpep_pickup_datetime);

-- 1.2 Hourly KPI Summary View
CREATE OR REPLACE VIEW uber_data_db.vw_hourly_kpis AS
SELECT 
    d.pick_hour,
    COUNT(*) as trips,
    ROUND(SUM(f.total_amount), 2) as revenue,
    ROUND(AVG(f.total_amount), 2) as avg_fare,
    ROUND(SUM(f.tip_amount), 2) as tips,
    ROUND(AVG(f.trip_distance), 2) as avg_distance
FROM uber_data_db.fact_table f
JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
GROUP BY d.pick_hour
ORDER BY d.pick_hour;

-- ============================================================
-- 2. KEY PERFORMANCE INDICATORS (KPIs)
-- ============================================================

-- 2.1 Overall KPIs Dashboard
SELECT 
    'Total Revenue' as kpi_name,
    ROUND(SUM(f.total_amount), 2) as kpi_value,
    'USD' as unit,
    'Higher is better' as direction
FROM uber_data_db.fact_table f
UNION ALL
SELECT 
    'Total Trips',
    COUNT(*)::DECIMAL,
    'Trips',
    'Higher is better'
FROM uber_data_db.fact_table
UNION ALL
SELECT 
    'Average Trip Value',
    ROUND(AVG(f.total_amount), 2),
    'USD',
    'Higher is better'
FROM uber_data_db.fact_table f
UNION ALL
SELECT 
    'Average Trip Distance',
    ROUND(AVG(t.trip_distance), 2),
    'Miles',
    'Higher is better'
FROM uber_data_db.fact_table f
JOIN uber_data_db.trip_distance_dim t ON f.trip_distance_id = t.trip_distance_id
UNION ALL
SELECT 
    'Total Tips',
    ROUND(SUM(f.tip_amount), 2),
    'USD',
    'Higher is better'
FROM uber_data_db.fact_table f
UNION ALL
SELECT 
    'Average Tip Percentage',
    ROUND(
        AVG(f.tip_amount / NULLIF(f.fare_amount, 0)) * 100, 
        2
    ),
    '%',
    'Higher is better'
FROM uber_data_db.fact_table f
UNION ALL
SELECT 
    'Tip Rate',
    ROUND(
        COUNT(CASE WHEN f.tip_amount > 0 THEN 1 END) * 100.0 / COUNT(*), 
        2
    ),
    '%',
    'Higher is better'
FROM uber_data_db.fact_table f;

-- ============================================================
-- 3. REVENUE METRICS
-- ============================================================

-- 3.1 Revenue Growth Rate
WITH daily_revenue AS (
    SELECT 
        DATE(d.tpep_pickup_datetime) as date,
        SUM(f.total_amount) as revenue
    FROM uber_data_db.fact_table f
    JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
    GROUP BY DATE(d.tpep_pickup_datetime)
)
SELECT 
    date,
    revenue,
    LAG(revenue, 1) OVER (ORDER BY date) as prev_day_revenue,
    ROUND(
        ((revenue - LAG(revenue, 1) OVER (ORDER BY date)) / 
         NULLIF(LAG(revenue, 1) OVER (ORDER BY date), 0)) * 100, 
        2
    ) as day_over_day_growth_pct,
    ROUND(
        ((revenue - LAG(revenue, 7) OVER (ORDER BY date)) / 
         NULLIF(LAG(revenue, 7) OVER (ORDER BY date), 0)) * 100, 
        2
    ) as week_over_week_growth_pct
FROM daily_revenue
ORDER BY date DESC
LIMIT 30;

-- 3.2 Revenue by Payment Method
SELECT 
    pay.payment_type_name,
    COUNT(*) as trips,
    ROUND(SUM(f.total_amount), 2) as total_revenue,
    ROUND(AVG(f.total_amount), 2) as avg_revenue,
    ROUND(
        SUM(f.total_amount) * 100.0 / SUM(SUM(f.total_amount)) OVER (), 
        2
    ) as revenue_share_pct
FROM uber_data_db.fact_table f
JOIN uber_data_db.payment_type_dim pay ON f.payment_type_id = pay.payment_type_id
GROUP BY pay.payment_type_name
ORDER BY total_revenue DESC;

-- ============================================================
-- 4. OPERATIONAL METRICS
-- ============================================================

-- 4.1 Trip Volume Metrics
SELECT 
    'Peak Hour' as metric,
    MAX(hour_data.trips) as value,
    hour_data.pick_hour as detail
FROM (
    SELECT 
        d.pick_hour,
        COUNT(*) as trips
    FROM uber_data_db.fact_table f
    JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
    GROUP BY d.pick_hour
    ORDER BY trips DESC
    LIMIT 1
) hour_data
UNION ALL
SELECT 
    'Average Trips per Hour',
    ROUND(AVG(hourly_trips.trips), 2),
    NULL
FROM (
    SELECT 
        d.pick_hour,
        COUNT(*) as trips
    FROM uber_data_db.fact_table f
    JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
    GROUP BY d.pick_hour
) hourly_trips;

-- 4.2 Distance Metrics
SELECT 
    'Average Trip Distance' as metric,
    ROUND(AVG(t.trip_distance), 2) as value,
    'Miles' as unit
FROM uber_data_db.fact_table f
JOIN uber_data_db.trip_distance_dim t ON f.trip_distance_id = t.trip_distance_id
UNION ALL
SELECT 
    'Total Distance Traveled',
    ROUND(SUM(t.trip_distance), 2),
    'Miles'
FROM uber_data_db.fact_table f
JOIN uber_data_db.trip_distance_dim t ON f.trip_distance_id = t.trip_distance_id
UNION ALL
SELECT 
    'Longest Trip',
    MAX(t.trip_distance),
    'Miles'
FROM uber_data_db.fact_table f
JOIN uber_data_db.trip_distance_dim t ON f.trip_distance_id = t.trip_distance_id;

-- ============================================================
-- 5. CUSTOMER METRICS (if applicable)
-- ============================================================

-- 5.1 Passenger Count Analysis
SELECT 
    p.passenger_count,
    COUNT(*) as trips,
    ROUND(SUM(f.total_amount), 2) as revenue,
    ROUND(AVG(f.total_amount), 2) as avg_fare,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
        2
    ) as trip_share_pct
FROM uber_data_db.fact_table f
JOIN uber_data_db.passenger_count_dim p ON f.passenger_count_id = p.passenger_count_id
GROUP BY p.passenger_count
ORDER BY p.passenger_count;

-- ============================================================
-- 6. PERFORMANCE TRACKING
-- ============================================================

-- 6.1 Monthly Performance Summary
SELECT 
    d.pick_year,
    d.pick_month,
    COUNT(*) as trips,
    ROUND(SUM(f.total_amount), 2) as revenue,
    ROUND(AVG(f.total_amount), 2) as avg_trip_value,
    ROUND(SUM(f.tip_amount), 2) as total_tips,
    ROUND(AVG(f.trip_distance), 2) as avg_distance
FROM uber_data_db.fact_table f
JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
GROUP BY d.pick_year, d.pick_month
ORDER BY d.pick_year, d.pick_month;

-- 6.2 Week-over-Week Performance
WITH weekly_metrics AS (
    SELECT 
        DATE_TRUNC('week', d.tpep_pickup_datetime) as week_start,
        COUNT(*) as trips,
        ROUND(SUM(f.total_amount), 2) as revenue
    FROM uber_data_db.fact_table f
    JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
    GROUP BY DATE_TRUNC('week', d.tpep_pickup_datetime)
)
SELECT 
    week_start,
    trips,
    revenue,
    LAG(trips, 1) OVER (ORDER BY week_start) as prev_week_trips,
    LAG(revenue, 1) OVER (ORDER BY week_start) as prev_week_revenue,
    ROUND(
        ((trips - LAG(trips, 1) OVER (ORDER BY week_start)) / 
         NULLIF(LAG(trips, 1) OVER (ORDER BY week_start), 0)) * 100, 
        2
    ) as trips_wow_change_pct,
    ROUND(
        ((revenue - LAG(revenue, 1) OVER (ORDER BY week_start)) / 
         NULLIF(LAG(revenue, 1) OVER (ORDER BY week_start), 0)) * 100, 
        2
    ) as revenue_wow_change_pct
FROM weekly_metrics
ORDER BY week_start DESC;

-- ============================================================
-- 7. EFFICIENCY METRICS
-- ============================================================

-- 7.1 Revenue per Mile
SELECT 
    ROUND(
        SUM(f.total_amount) / NULLIF(SUM(t.trip_distance), 0), 
        2
    ) as revenue_per_mile,
    ROUND(
        AVG(f.total_amount / NULLIF(t.trip_distance, 0)), 
        2
    ) as avg_revenue_per_mile
FROM uber_data_db.fact_table f
JOIN uber_data_db.trip_distance_dim t ON f.trip_distance_id = t.trip_distance_id;

-- 7.2 Tip Efficiency
SELECT 
    pay.payment_type_name,
    COUNT(*) as trips,
    ROUND(SUM(f.tip_amount), 2) as total_tips,
    ROUND(AVG(f.tip_amount), 2) as avg_tip,
    ROUND(
        COUNT(CASE WHEN f.tip_amount > 0 THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as tip_rate_pct
FROM uber_data_db.fact_table f
JOIN uber_data_db.payment_type_dim pay ON f.payment_type_id = pay.payment_type_id
GROUP BY pay.payment_type_name
ORDER BY total_tips DESC;

-- ============================================================
-- END OF BUSINESS METRICS QUERIES
-- ============================================================

