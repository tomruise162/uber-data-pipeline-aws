-- ============================================================
-- Advanced Analytics Queries for Uber Data
-- Step 08: Advanced Analytics for Data Analyst
-- ============================================================
-- These queries demonstrate advanced analytical capabilities:
-- - Statistical Analysis
-- - Time-series Analysis
-- - Cohort Analysis
-- - Correlation Analysis
-- - Percentile Analysis
-- - Trend Analysis
-- ============================================================

-- ============================================================
-- 1. STATISTICAL ANALYSIS
-- ============================================================

-- 1.1 Descriptive Statistics for Revenue
SELECT 
    COUNT(*) as total_trips,
    ROUND(SUM(total_amount), 2) as total_revenue,
    ROUND(AVG(total_amount), 2) as mean_revenue,
    ROUND(STDDEV(total_amount), 2) as std_dev_revenue,
    ROUND(MIN(total_amount), 2) as min_revenue,
    ROUND(MAX(total_amount), 2) as max_revenue,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount), 2) as median_revenue,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_amount), 2) as q1_revenue,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_amount), 2) as q3_revenue
FROM uber_data_db.fact_table f
JOIN uber_data_db.tbl_analytics t ON f.trip_id = t.trip_id;

-- 1.2 Revenue Distribution by Percentiles
SELECT 
    'P10' as percentile, PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY total_amount) as value
FROM uber_data_db.tbl_analytics
UNION ALL
SELECT 'P25', PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_amount)
UNION ALL
SELECT 'P50 (Median)', PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_amount)
UNION ALL
SELECT 'P75', PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_amount)
UNION ALL
SELECT 'P90', PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_amount)
UNION ALL
SELECT 'P95', PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_amount)
UNION ALL
SELECT 'P99', PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_amount);

-- ============================================================
-- 2. TIME-SERIES ANALYSIS
-- ============================================================

-- 2.1 Revenue Trend by Day (Moving Average)
WITH daily_revenue AS (
    SELECT 
        DATE(d.tpep_pickup_datetime) as trip_date,
        COUNT(*) as trips,
        ROUND(SUM(f.total_amount), 2) as daily_revenue
    FROM uber_data_db.fact_table f
    JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
    GROUP BY DATE(d.tpep_pickup_datetime)
)
SELECT 
    trip_date,
    trips,
    daily_revenue,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY trip_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) as moving_avg_7days,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY trip_date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) as moving_avg_30days
FROM daily_revenue
ORDER BY trip_date;

-- 2.2 Week-over-Week Growth
WITH weekly_revenue AS (
    SELECT 
        DATE_TRUNC('week', d.tpep_pickup_datetime) as week_start,
        COUNT(*) as trips,
        ROUND(SUM(f.total_amount), 2) as weekly_revenue
    FROM uber_data_db.fact_table f
    JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
    GROUP BY DATE_TRUNC('week', d.tpep_pickup_datetime)
)
SELECT 
    week_start,
    trips,
    weekly_revenue,
    LAG(weekly_revenue, 1) OVER (ORDER BY week_start) as prev_week_revenue,
    ROUND(
        ((weekly_revenue - LAG(weekly_revenue, 1) OVER (ORDER BY week_start)) / 
         NULLIF(LAG(weekly_revenue, 1) OVER (ORDER BY week_start), 0)) * 100, 
        2
    ) as wow_growth_pct
FROM weekly_revenue
ORDER BY week_start;

-- ============================================================
-- 3. COHORT ANALYSIS
-- ============================================================

-- 3.1 Customer Retention by Payment Type (if customer_id exists)
-- Note: This is a template - adjust based on available customer data
SELECT 
    pay.payment_type_name,
    DATE_TRUNC('month', d.tpep_pickup_datetime) as cohort_month,
    COUNT(DISTINCT f.trip_id) as trips,
    ROUND(SUM(f.total_amount), 2) as cohort_revenue
FROM uber_data_db.fact_table f
JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
JOIN uber_data_db.payment_type_dim pay ON f.payment_type_id = pay.payment_type_id
GROUP BY pay.payment_type_name, DATE_TRUNC('month', d.tpep_pickup_datetime)
ORDER BY cohort_month, pay.payment_type_name;

-- ============================================================
-- 4. CORRELATION ANALYSIS
-- ============================================================

-- 4.1 Correlation: Trip Distance vs Revenue
SELECT 
    ROUND(
        CORR(t.trip_distance, f.total_amount), 
        4
    ) as distance_revenue_correlation,
    ROUND(
        CORR(p.passenger_count, f.total_amount), 
        4
    ) as passenger_revenue_correlation,
    ROUND(
        CORR(t.trip_distance, f.tip_amount), 
        4
    ) as distance_tip_correlation
FROM uber_data_db.fact_table f
JOIN uber_data_db.trip_distance_dim t ON f.trip_distance_id = t.trip_distance_id
JOIN uber_data_db.passenger_count_dim p ON f.passenger_count_id = p.passenger_count_id;

-- ============================================================
-- 5. ANOMALY DETECTION
-- ============================================================

-- 5.1 Outliers: Trips with unusually high/low revenue
WITH revenue_stats AS (
    SELECT 
        AVG(total_amount) as mean_revenue,
        STDDEV(total_amount) as std_revenue
    FROM uber_data_db.tbl_analytics
)
SELECT 
    t.trip_id,
    t.tpep_pickup_datetime,
    t.trip_distance,
    t.total_amount,
    CASE 
        WHEN t.total_amount > (rs.mean_revenue + 3 * rs.std_revenue) THEN 'High Outlier'
        WHEN t.total_amount < (rs.mean_revenue - 3 * rs.std_revenue) THEN 'Low Outlier'
        ELSE 'Normal'
    END as outlier_type
FROM uber_data_db.tbl_analytics t
CROSS JOIN revenue_stats rs
WHERE t.total_amount > (rs.mean_revenue + 3 * rs.std_revenue)
   OR t.total_amount < (rs.mean_revenue - 3 * rs.std_revenue)
ORDER BY t.total_amount DESC
LIMIT 50;

-- ============================================================
-- 6. SEGMENTATION ANALYSIS
-- ============================================================

-- 6.1 Revenue Segments (High/Medium/Low)
SELECT 
    CASE 
        WHEN total_amount >= 50 THEN 'High Value (>= $50)'
        WHEN total_amount >= 20 THEN 'Medium Value ($20-$50)'
        ELSE 'Low Value (< $20)'
    END as revenue_segment,
    COUNT(*) as trip_count,
    ROUND(SUM(total_amount), 2) as segment_revenue,
    ROUND(AVG(total_amount), 2) as avg_revenue,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_trips
FROM uber_data_db.tbl_analytics
GROUP BY 
    CASE 
        WHEN total_amount >= 50 THEN 'High Value (>= $50)'
        WHEN total_amount >= 20 THEN 'Medium Value ($20-$50)'
        ELSE 'Low Value (< $20)'
    END
ORDER BY segment_revenue DESC;

-- ============================================================
-- 7. COMPARATIVE ANALYSIS
-- ============================================================

-- 7.1 Payment Type Performance Comparison
SELECT 
    pay.payment_type_name,
    COUNT(*) as trips,
    ROUND(SUM(f.total_amount), 2) as total_revenue,
    ROUND(AVG(f.total_amount), 2) as avg_revenue,
    ROUND(AVG(f.tip_amount), 2) as avg_tip,
    ROUND(
        AVG(f.tip_amount / NULLIF(f.fare_amount, 0)) * 100, 
        2
    ) as avg_tip_percentage,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
        2
    ) as market_share_pct
FROM uber_data_db.fact_table f
JOIN uber_data_db.payment_type_dim pay ON f.payment_type_id = pay.payment_type_id
GROUP BY pay.payment_type_name
ORDER BY total_revenue DESC;

-- ============================================================
-- 8. BUSINESS METRICS
-- ============================================================

-- 8.1 Key Performance Indicators (KPIs)
SELECT 
    'Total Revenue' as metric,
    ROUND(SUM(f.total_amount), 2) as value
FROM uber_data_db.fact_table f
UNION ALL
SELECT 
    'Total Trips',
    COUNT(*)::VARCHAR
FROM uber_data_db.fact_table
UNION ALL
SELECT 
    'Average Trip Value',
    ROUND(AVG(f.total_amount), 2)::VARCHAR
FROM uber_data_db.fact_table f
UNION ALL
SELECT 
    'Total Tips',
    ROUND(SUM(f.tip_amount), 2)::VARCHAR
FROM uber_data_db.fact_table f
UNION ALL
SELECT 
    'Average Tip Percentage',
    ROUND(
        AVG(f.tip_amount / NULLIF(f.fare_amount, 0)) * 100, 
        2
    )::VARCHAR || '%'
FROM uber_data_db.fact_table f;

-- ============================================================
-- 9. PATTERN ANALYSIS
-- ============================================================

-- 9.1 Peak Hours Analysis
SELECT 
    d.pick_hour,
    COUNT(*) as trips,
    ROUND(SUM(f.total_amount), 2) as revenue,
    ROUND(AVG(f.total_amount), 2) as avg_fare,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
        2
    ) as pct_of_total_trips
FROM uber_data_db.fact_table f
JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
GROUP BY d.pick_hour
ORDER BY trips DESC;

-- 9.2 Day of Week Patterns
SELECT 
    CASE d.pick_weekday
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END as day_of_week,
    COUNT(*) as trips,
    ROUND(SUM(f.total_amount), 2) as revenue,
    ROUND(AVG(f.total_amount), 2) as avg_fare
FROM uber_data_db.fact_table f
JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
GROUP BY d.pick_weekday
ORDER BY d.pick_weekday;

-- ============================================================
-- 10. ADVANCED AGGREGATIONS
-- ============================================================

-- 10.1 Top N Analysis with Window Functions
SELECT 
    rate_code_name,
    trips,
    revenue,
    revenue_rank
FROM (
    SELECT 
        r.rate_code_name,
        COUNT(*) as trips,
        ROUND(SUM(f.total_amount), 2) as revenue,
        RANK() OVER (ORDER BY SUM(f.total_amount) DESC) as revenue_rank
    FROM uber_data_db.fact_table f
    JOIN uber_data_db.rate_code_dim r ON f.rate_code_id = r.rate_code_id
    GROUP BY r.rate_code_name
) ranked
WHERE revenue_rank <= 5
ORDER BY revenue_rank;

-- ============================================================
-- END OF ADVANCED ANALYTICS QUERIES
-- ============================================================

