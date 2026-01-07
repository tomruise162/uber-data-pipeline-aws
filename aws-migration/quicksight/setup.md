# Amazon QuickSight Setup Guide

## Overview

Amazon QuickSight is AWS's business intelligence service for creating interactive dashboards and visualizations. This guide will help you set up QuickSight to visualize the Uber trip data.

## Prerequisites

- AWS Account with QuickSight access
- Athena tables created and populated
- Glue Data Catalog configured

## Step 1: Sign up for QuickSight

1. Go to [QuickSight Console](https://quicksight.aws.amazon.com/)
2. Click "Sign up for QuickSight"
3. Choose **Standard Edition** (or Enterprise if needed)
4. Account name: `uber-analytics` (or your choice)
5. Email: Your email address
6. Region: Same as your S3 bucket region
7. Click "Finish"

**Cost**: Standard Edition is $9/user/month (first 30 days free)

## Step 2: Grant QuickSight Access to Athena and S3

1. In QuickSight, click your profile icon (top right)
2. Select "Manage QuickSight"
3. Click "Security & permissions"
4. Click "Add or remove" under "QuickSight access to AWS services"
5. Check the following:
   - ✅ **Amazon Athena**
   - ✅ **Amazon S3**
6. For S3, click "Select S3 buckets"
7. Select your bucket: `uber-etl-pipeline-*`
8. Click "Finish"

## Step 3: Create Athena Data Source

1. In QuickSight, click "Datasets" (left menu)
2. Click "New dataset"
3. Choose "Athena" as data source
4. Data source name: `uber-data-athena`
5. Athena workgroup: `primary` (or your custom workgroup)
6. Click "Create data source"

## Step 4: Select Tables

1. Database: Select `uber_data_db`
2. Tables: Select `tbl_analytics` (the view we created)
3. Click "Select"

## Step 5: Configure Data Import

You have two options:

### Option A: SPICE (Recommended for small datasets)
- Faster query performance
- Data is imported into QuickSight's in-memory engine
- Refreshes on schedule
- **Choose this for the Uber dataset**

### Option B: Direct Query
- Queries Athena directly each time
- Always up-to-date
- Slower performance
- Higher Athena costs

**Select**: "Import to SPICE for quicker analytics"

Click "Visualize"

## Step 6: Create Visualizations

### Dashboard 1: Revenue Overview

1. **Total Revenue Card**
   - Visual type: KPI
   - Value: `total_amount` (SUM)
   - Title: "Total Revenue"

2. **Total Trips Card**
   - Visual type: KPI
   - Value: `trip_id` (COUNT)
   - Title: "Total Trips"

3. **Revenue by Payment Type**
   - Visual type: Pie chart
   - Group by: `payment_type_name`
   - Value: `total_amount` (SUM)

4. **Trips by Hour**
   - Visual type: Line chart
   - X-axis: `tpep_pickup_datetime` (Hour)
   - Y-axis: `trip_id` (COUNT)

### Dashboard 2: Trip Analysis

1. **Average Fare by Passenger Count**
   - Visual type: Bar chart
   - X-axis: `passenger_count`
   - Y-axis: `total_amount` (AVG)

2. **Trip Distance Distribution**
   - Visual type: Histogram
   - X-axis: `trip_distance`
   - Bins: 10

3. **Revenue by Rate Code**
   - Visual type: Horizontal bar chart
   - Y-axis: `rate_code_name`
   - X-axis: `total_amount` (SUM)

### Dashboard 3: Geographic Analysis

1. **Pickup Locations Map**
   - Visual type: Points on map
   - Geospatial: `pickup_latitude`, `pickup_longitude`
   - Size: `total_amount` (SUM)

2. **Dropoff Locations Map**
   - Visual type: Points on map
   - Geospatial: `dropoff_latitude`, `dropoff_longitude`
   - Size: `trip_id` (COUNT)

## Step 7: Add Filters

Add interactive filters to your dashboard:

1. Click "Filter" (left panel)
2. Add filters:
   - `tpep_pickup_datetime` - Date range filter
   - `payment_type_name` - Multi-select
   - `rate_code_name` - Multi-select
   - `passenger_count` - Range filter

## Step 8: Format and Customize

1. **Add Dashboard Title**
   - Click "Add" → "Text box"
   - Title: "Uber Trip Analytics Dashboard"

2. **Apply Theme**
   - Click "Themes" (top menu)
   - Choose a theme (e.g., "Midnight", "Seaside")

3. **Arrange Visuals**
   - Drag and resize visuals
   - Use grid layout for alignment

## Step 9: Publish Dashboard

1. Click "Share" (top right)
2. Click "Publish dashboard"
3. Dashboard name: `Uber Analytics Dashboard`
4. Click "Publish"

## Step 10: Schedule Data Refresh

1. Go to "Datasets"
2. Select `tbl_analytics`
3. Click "Schedule refresh"
4. Set schedule:
   - Frequency: Daily
   - Time: 2:00 AM
   - Time zone: Your timezone
5. Click "Save"

## Sample Dashboard Layout

```
┌─────────────────────────────────────────────────────┐
│         Uber Trip Analytics Dashboard               │
├──────────────┬──────────────┬────────────────────────┤
│ Total Revenue│  Total Trips │  Avg Fare              │
│   $12,345    │    1,000     │   $12.35               │
├──────────────┴──────────────┴────────────────────────┤
│                                                       │
│  Revenue by Payment Type    │  Trips by Hour         │
│  [Pie Chart]                │  [Line Chart]          │
│                             │                        │
├─────────────────────────────┼────────────────────────┤
│  Trip Distance Distribution │  Revenue by Rate Code  │
│  [Histogram]                │  [Bar Chart]           │
│                             │                        │
├─────────────────────────────┴────────────────────────┤
│  Pickup Locations Map                                │
│  [Geographic Map]                                    │
│                                                       │
└─────────────────────────────────────────────────────┘
```

## Sharing Dashboards

### Share with AWS Users
1. Click "Share" → "Share dashboard"
2. Enter AWS user email
3. Set permissions (Viewer/Co-owner)
4. Click "Share"

### Embed in Website (Enterprise only)
1. Click "Share" → "Embed"
2. Copy embed code
3. Add to your website

## Tips and Best Practices

1. **Use SPICE for better performance**
   - Refresh data on schedule
   - Faster than direct Athena queries

2. **Create calculated fields**
   - Example: `tip_percentage = tip_amount / fare_amount * 100`
   - Example: `trip_duration = dateDiff(tpep_dropoff_datetime, tpep_pickup_datetime)`

3. **Use parameters for dynamic filtering**
   - Create date range parameters
   - Allow users to select custom ranges

4. **Optimize visuals**
   - Limit data points in charts
   - Use aggregations
   - Add top N filters

5. **Monitor costs**
   - SPICE capacity: 10GB free, then $0.25/GB/month
   - Athena queries: $5/TB scanned
   - Use partitioning to reduce scan costs

## Troubleshooting

### Issue: "Insufficient permissions"
**Solution**: Grant QuickSight access to S3 and Athena (see Step 2)

### Issue: "No data in visualizations"
**Solution**: 
- Check Athena query results
- Verify Glue tables have data
- Refresh SPICE dataset

### Issue: "Query timeout"
**Solution**:
- Use SPICE instead of direct query
- Optimize Athena queries
- Partition data in S3

## Next Steps

- Create additional dashboards for specific analyses
- Set up email reports
- Configure alerts for anomalies
- Integrate with other AWS services (Lambda, SNS)

## Resources

- [QuickSight Documentation](https://docs.aws.amazon.com/quicksight/)
- [QuickSight Pricing](https://aws.amazon.com/quicksight/pricing/)
- [QuickSight Gallery](https://aws.amazon.com/quicksight/gallery/)
