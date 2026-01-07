# AWS Migration - Uber ETL Pipeline

## Overview

This folder contains all AWS-specific implementations for the Uber ETL pipeline using AWS-only services.

**Architecture**: Fully serverless using AWS Glue, S3, Athena, and QuickSight.

## AWS Services Used

- **Amazon S3**: Raw and processed data storage
- **AWS Glue**: ETL jobs and data catalog
- **Amazon Athena**: Serverless SQL queries
- **Amazon QuickSight**: Business intelligence and visualization
- **AWS IAM**: Access management

## Folder Structure

```
aws-migration/
├── README.md                    # This file
├── s3_setup.md                  # S3 bucket configuration
├── glue/
│   ├── extract_job.py          # Glue job: Extract data from S3
│   ├── transform_job.py        # Glue job: Transform to star schema
│   └── load_job.py             # Glue job: Load to S3 + Catalog
├── athena/
│   └── queries.sql             # Athena SQL queries
├── quicksight/
│   └── setup.md                # QuickSight dashboard setup
└── terraform/
    ├── main.tf                 # Main infrastructure
    ├── variables.tf            # Variables
    └── outputs.tf              # Outputs
```

## Quick Start

### Prerequisites

1. AWS Account with appropriate permissions
2. AWS CLI installed and configured
3. Terraform installed (optional, for IaC)

### Setup Steps

1. **Create S3 Buckets** - Follow [s3_setup.md](s3_setup.md)
2. **Upload Raw Data** - Upload `uber_data.csv` to S3
3. **Deploy Glue Jobs** - Deploy ETL jobs from `glue/` folder
4. **Run Pipeline** - Execute Glue jobs in order
5. **Query with Athena** - Run queries from `athena/queries.sql`
6. **Visualize** - Setup QuickSight dashboards

## Cost Estimate

For the sample dataset (~100KB):
- S3: < $0.01/month
- Glue: ~$0.44/DPU-hour (only when running)
- Athena: $5/TB scanned (minimal for this dataset)
- QuickSight: $9/user/month or free tier

**Total**: < $10/month for occasional runs

## Important: Creating Tables in Glue Data Catalog

**RECOMMENDED Approach:** Use Glue Crawler to create tables (see Step 5 below)

The Load job (`load_job.py`) is **optional**. For Data Lake + Athena workflows, **Crawler is more reliable** than using `saveAsTable()` in Load job.

See [PIPELINE_WORKFLOW.md](PIPELINE_WORKFLOW.md) for detailed explanation of the correct workflow.

## Quick Start Workflow

1. **Upload Data & Scripts** → `01-upload-to-s3.bat`
2. **Create IAM Role** → `02-create-iam-role.bat`
3. **Create Glue Database & Jobs** → `03-create-glue-jobs.bat`
4. **Run ETL Jobs** → Extract + Transform (Load job is optional)
5. **Create Tables with Crawler** → `05-create-glue-crawler.bat` ← **RECOMMENDED**
   - Creates 2 crawlers (idempotent):
     - `uber-etl-crawler-extracted` (optional, for verification)
     - `uber-etl-crawler-curated` (main, creates 8 tables)
6. **Query with Athena**
7. **(Optional) Re-run Crawler** → `06-run-crawler-curated.bat` (after Transform job updates)

## Next Steps

- See [PIPELINE_WORKFLOW.md](PIPELINE_WORKFLOW.md) for detailed workflow and troubleshooting
- See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for step-by-step instructions
