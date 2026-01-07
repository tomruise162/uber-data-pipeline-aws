# Pipeline Workflow Documentation

## Overview

This document describes the complete workflow for deploying and operating the Uber ETL pipeline on AWS. The pipeline uses AWS Glue for ETL processing, S3 for data storage, Glue Data Catalog for metadata management, and Amazon Athena for querying. Visualization is performed using Power BI.

## Architecture Overview

The pipeline follows a serverless architecture pattern:

```
Raw CSV Data (S3)
    ↓
[Extract Job] → Parquet Files (processed-data/extracted/)
    ↓
[Transform Job] → Star Schema Parquet Files (8 dimension/fact tables)
    ↓
[Glue Crawler] → Tables in Glue Data Catalog
    ↓
[Amazon Athena] → SQL Queries
    ↓
[Power BI] → Business Intelligence Dashboards
```

## Key Design Decisions

### Table Creation Strategy

The pipeline uses **AWS Glue Crawler** to create tables in the Glue Data Catalog instead of using Spark's `saveAsTable()` method. This approach is recommended because:

1. **Reliability**: Crawler automatically infers schema from Parquet files
2. **Simplicity**: No need to configure Spark metastore connections
3. **Best Practice**: Aligns with AWS Data Lake architecture patterns
4. **Maintainability**: Easier to debug and update table schemas

**Alternative Approach**: The Load job (`load_job.py`) can be configured to use Glue Catalog by setting Spark configuration, but this is more complex and not recommended for beginners.

## Deployment Workflow

### Step 1: Upload Data and Scripts

**Script**: `01-upload-to-s3.bat`

**Actions**:
- Uploads raw CSV data to S3 bucket
- Uploads Glue job scripts to S3
- Creates required folder structure in S3

**Prerequisites**:
- AWS CLI configured with appropriate credentials
- S3 bucket created

### Step 2: Create IAM Role

**Script**: `02-create-iam-role.bat`

**Actions**:
- Creates IAM role for AWS Glue jobs
- Attaches policies for:
  - S3 access (GetObject, PutObject, ListBucket)
  - Glue Catalog access (CreateTable, UpdateTable) - **Required**
  - CloudWatch Logs for monitoring

**Important**: The IAM role must have Glue Catalog permissions to create tables.

### Step 3: Create Glue Database and Jobs

**Script**: `03-create-glue-jobs.bat`

**Actions**:
- Creates Glue database: `uber_data_db`
- Creates Extract job: `uber-etl-extract-job`
- Creates Transform job: `uber-etl-transform-job`
- Load job is optional (not recommended, use Crawler instead)

### Step 4: Execute ETL Jobs

**Execution**: Via AWS Console or CLI

**Job Sequence**:
1. Run `uber-etl-extract-job`
   - Reads raw CSV from S3
   - Writes Parquet files to `processed-data/extracted/`

2. Run `uber-etl-transform-job`
   - Reads from `processed-data/extracted/`
   - Transforms to star schema
   - Writes 8 separate Parquet folders:
     - `datetime_dim/`
     - `passenger_count_dim/`
     - `trip_distance_dim/`
     - `rate_code_dim/`
     - `pickup_location_dim/`
     - `dropoff_location_dim/`
     - `payment_type_dim/`
     - `fact_table/`

**Expected Result**: All Parquet files written to S3 in organized folder structure.

### Step 5: Create Tables Using Glue Crawler

**Script**: `05-create-glue-crawler.bat`

**Actions**:
- Creates two crawlers (idempotent - safe to run multiple times):
  1. `uber-etl-crawler-extracted` - Crawls `processed-data/extracted/` (optional, for verification)
  2. `uber-etl-crawler-curated` - Crawls 8 dimension/fact folders (main, required)

**Process**:
- Crawlers scan S3 folders
- Automatically infer schema from Parquet files
- Create tables in Glue Data Catalog
- Tables are immediately available for Athena queries

**Expected Result**: 8 tables in Glue Data Catalog (or 9 if extracted table is crawled).

**Two-Stage Crawler Design**:
- Extract job writes to `processed-data/extracted/`
- Transform job reads from `extracted/` and writes to separate dimension/fact folders
- Two separate crawlers handle each stage appropriately

### Step 6: Query Data with Athena

**Access**: AWS Athena Console

**Actions**:
- Select database: `uber_data_db`
- Execute SQL queries against created tables
- Export results as needed

**Example Queries**:
```sql
-- List all tables
SHOW TABLES IN uber_data_db;

-- Query fact table
SELECT * FROM uber_data_db.fact_table LIMIT 10;

-- Revenue analysis
SELECT 
    COUNT(*) as total_trips,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_fare
FROM uber_data_db.fact_table;
```

### Step 7: Connect Power BI for Visualization

**Process**:
1. Install Power BI Desktop
2. Connect to Amazon Athena using ODBC driver
3. Import tables from `uber_data_db`
4. Create data model and relationships
5. Build dashboards and reports
6. Publish to Power BI Service (optional)

**Connection Details**:
- Data Source: Amazon Athena
- Database: `uber_data_db`
- Authentication: AWS credentials
- Region: Same as S3 bucket region

**Note**: Power BI connects directly to Athena, which queries the Glue Data Catalog tables. No additional data export is required.

### Step 8: Re-run Crawler (When Needed)

**Script**: `06-run-crawler-curated.bat`

**Use Case**: After re-running Transform job to update data

**Actions**:
- Starts the curated crawler (does not recreate it)
- Updates table schemas if structure changed
- Refreshes metadata in Glue Data Catalog

## Alternative Workflow: Using Load Job

If you prefer to use the Load job instead of Crawler:

1. Complete Steps 1-4 as described above
2. Instead of Step 5, run `uber-etl-load-job`
   - Load job must be configured to use Glue Catalog metastore
   - Will create tables in Glue Data Catalog

**Note**: Crawler approach is still recommended for simplicity and reliability.

## Troubleshooting

### Issue: Database Shows 0 Tables

**Possible Causes**:
1. Crawler has not been run
2. Crawler target path is incorrect
3. IAM role missing `glue:CreateTable` permission
4. Load job not configured for Glue Catalog (if using Load job)

**Solutions**:
1. Run `05-create-glue-crawler.bat`
2. Verify crawler targets point to correct S3 paths
3. Check IAM role permissions in AWS Console
4. If using Load job, ensure Glue Catalog metastore is configured

### Issue: Crawler Creates Only 1 Table Instead of 8

**Possible Causes**:
- Crawler pointing to root `processed-data/` instead of individual folders
- Crawler crawling `extracted/` instead of dimension/fact folders

**Solution**:
- Verify `05-create-glue-crawler.bat` configuration
- Ensure `uber-etl-crawler-curated` targets all 8 folders separately
- Each folder should map to one table

### Issue: Need to Run Crawler Twice

**Explanation**:
This is expected behavior for the two-stage workflow:
1. First run: Crawl `extracted/` folder (optional verification)
2. Second run: Crawl dimension/fact folders (main tables)

**Solution**:
- Script `05-create-glue-crawler.bat` creates both crawlers automatically
- After initial setup, use `06-run-crawler-curated.bat` for updates
- Only the curated crawler needs to run after Transform job updates

## Data Flow Summary

1. **Extract Stage**: Raw CSV → Parquet in `extracted/` folder
2. **Transform Stage**: Parquet → Star schema in 8 separate folders
3. **Catalog Stage**: Crawler creates tables in Glue Data Catalog
4. **Query Stage**: Athena queries tables via SQL
5. **Visualization Stage**: Power BI connects to Athena for dashboards

## Deployment Checklist

- [ ] Step 1: Upload data and scripts to S3
- [ ] Step 2: Create IAM role with Glue Catalog permissions
- [ ] Step 3: Create Glue database and jobs
- [ ] Step 4: Execute Extract and Transform jobs
- [ ] Step 5: Run crawler creation script (creates 8 tables)
  - [ ] Verify crawler extracted (optional)
  - [ ] Verify crawler curated (main)
- [ ] Step 6: Verify tables in Glue Console (8 tables expected)
- [ ] Step 7: Test queries in Athena
- [ ] Step 8: Connect Power BI to Athena
- [ ] Step 9: Build Power BI dashboards
- [ ] (Optional) Step 10: Re-run crawler if data updated

## References

- [AWS Glue Crawler Documentation](https://docs.aws.amazon.com/glue/latest/dg/add-crawler.html)
- [AWS Glue Data Catalog](https://docs.aws.amazon.com/glue/latest/dg/catalog-and-crawler.html)
- [Amazon Athena Best Practices](https://docs.aws.amazon.com/athena/latest/ug/best-practices.html)
- [Power BI Amazon Athena Connector](https://docs.microsoft.com/en-us/power-bi/connect-data/service-connect-to-amazon-athena)
