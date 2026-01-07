# Uber ETL Pipeline - Data Engineering Project

A comprehensive end-to-end ETL pipeline for processing Uber trip data, built with AWS serverless services and Power BI for visualization.

## Project Overview

This project demonstrates a production-ready data engineering pipeline that:
- **Extracts** raw Uber trip data from CSV files
- **Transforms** data into a star schema data model
- **Loads** processed data into AWS S3 and creates analytics-ready tables
- **Visualizes** insights using Power BI dashboards

## Architecture

```
Raw Data (CSV) 
    ↓
AWS S3 (Raw Layer)
    ↓
AWS Glue (ETL Jobs)
    ├── Extract Job
    ├── Transform Job
    └── Load Job
    ↓
AWS S3 (Curated Layer)
    ↓
AWS Glue Data Catalog
    ↓
Amazon Athena (Query)
    ↓
Power BI (Visualization)
```

## Tech Stack

- **ETL**: AWS Glue (PySpark)
- **Storage**: Amazon S3
- **Data Catalog**: AWS Glue Data Catalog
- **Query Engine**: Amazon Athena
- **Infrastructure as Code**: Terraform
- **Visualization**: Power BI
- **Data Quality**: Python scripts

## Project Structure

```
uber-etl-pipeline-data-engineering-project/
├── aws-migration/
│   ├── glue/
│   │   ├── extract_job.py      # Extract raw data from S3
│   │   ├── transform_job.py     # Transform to star schema
│   │   └── load_job.py          # Load to curated layer
│   ├── terraform/
│   │   ├── main.tf              # Infrastructure definition
│   │   ├── variables.tf        # Terraform variables
│   │   └── outputs.tf          # Output values
│   ├── data-quality/
│   │   └── 07-data-quality-check.py
│   ├── analytics/
│   │   ├── 08-advanced-analytics.sql
│   │   └── 11-business-metrics.sql
│   ├── *.bat                    # Deployment scripts
│   └── *.sql                    # Athena queries
├── data/
│   └── *.csv                    # Sample data files
└── report/
    └── *.pbix                   # Power BI reports
```

## Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Python 3.8+ (for local development)
- Terraform 1.0+ (optional, for IaC)
- Power BI Desktop (for visualization)

### AWS Setup

1. **Configure AWS CLI**
   ```bash
   aws configure
   ```

2. **Create S3 Buckets**
   - Raw data bucket: `uber-etl-raw-{account-id}`
   - Curated data bucket: `uber-etl-curated-{account-id}`

3. **Upload Data**
   ```bash
   aws s3 cp data/uber_data.csv s3://uber-etl-raw-{account-id}/raw/
   ```

4. **Deploy Glue Jobs**
   - Use the provided `.bat` scripts or deploy via AWS Console
   - Jobs: `uber-etl-extract`, `uber-etl-transform`, `uber-etl-load`

5. **Run ETL Pipeline**
   - Execute jobs in order: Extract → Transform → Load
   - Monitor via AWS Glue Console

6. **Query Data**
   - Use Amazon Athena to query the curated tables
   - Sample queries in `analytics/` folder

### Local Development

```bash
# Install dependencies (if any)
pip install -r requirements.txt

# Run data quality checks
python aws-migration/data-quality/07-data-quality-check.py
```

## Data Model

The pipeline transforms raw data into a **star schema** with:

- **Fact Table**: `fact_trips`
- **Dimension Tables**:
  - `dim_payment_type`
  - `dim_passenger_count`
  - `dim_pickup_hour`
  - `dim_distance_bucket`

## Analytics & Visualization

### Power BI Dashboards

The project includes Power BI reports with:
- Executive Dashboard (KPIs, revenue trends, payment analysis)
- Business Performance (payment analysis, time analysis, passenger insights)
- Risk & Quality (dispute monitoring and analysis)

### Key Metrics

- Total Revenue
- Total Trips
- Average Fare
- Dispute Rate
- Revenue by Payment Type
- Revenue by Hour
- Passenger Count Analysis

## Configuration

### Environment Variables

Set the following in your AWS Glue job parameters:
- `S3_BUCKET`: Your S3 bucket name
- `RAW_DATA_PATH`: Path to raw data in S3
- `OUTPUT_PATH`: Path for processed data

### Terraform Variables

Edit `terraform/variables.tf` to customize:
- `aws_region`: AWS region
- `project_name`: Project name
- `environment`: Environment (dev/staging/prod)

## Scripts

- `01-upload-to-s3.bat`: Upload data and scripts to S3
- `02-create-iam-role.bat`: Create IAM role for Glue
- `03-create-glue-jobs.bat`: Create Glue jobs
- `04-run-glue-jobs.bat`: Execute ETL pipeline
- `05-create-glue-crawler.bat`: Create Glue crawlers
- `06-run-athena-queries.sql`: Sample Athena queries

## Data Quality

The pipeline includes data quality checks:
- Null value detection
- Data type validation
- Range checks
- Duplicate detection

Run quality checks:
```bash
python aws-migration/data-quality/07-data-quality-check.py
```

## Cost Estimate

For a dataset of ~100K records:
- **S3 Storage**: < $0.01/month
- **AWS Glue**: ~$0.44/DPU-hour (only when running)
- **Amazon Athena**: $5/TB scanned (minimal for this dataset)
- **Total**: < $10/month for occasional runs

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is for educational purposes.

## Author

Data Engineering Project - Uber ETL Pipeline

## Acknowledgments

- AWS Glue documentation
- Power BI community
- Data engineering best practices

---

**Note**: This is a demonstration project. Adjust configurations and security settings for production use.

