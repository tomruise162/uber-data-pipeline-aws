# AWS Migration Guide

## Complete Step-by-Step Guide to Deploy Uber ETL Pipeline on AWS

This guide will walk you through deploying the entire Uber ETL pipeline using AWS services.

## Prerequisites

Before starting, ensure you have:

1. **AWS Account** with administrator access
2. **AWS CLI** installed and configured
   ```bash
   aws --version
   aws configure
   ```
3. **Terraform** installed (optional, for IaC deployment)
   ```bash
   terraform --version
   ```
4. **Python 3.8+** (for local testing)

## Deployment Options

Choose one of the following deployment methods:

### Option A: Terraform (Recommended - Automated)
Fastest and most reproducible method.

### Option B: AWS Console (Manual)
Good for learning and understanding each component.

### Option C: AWS CLI (Semi-automated)
Balance between automation and control.

---

## Option A: Terraform Deployment

### Step 1: Configure Terraform

```bash
cd aws-migration/terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

When prompted, type `yes` to confirm.

### Step 2: Upload Raw Data

```bash
# Get bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# Upload CSV file
aws s3 cp ../../data/uber_data.csv s3://$BUCKET_NAME/raw-data/uber_data.csv

# Verify upload
aws s3 ls s3://$BUCKET_NAME/raw-data/
```

### Step 3: Run Glue Jobs

```bash
# Get job names from Terraform output
EXTRACT_JOB=$(terraform output -raw glue_extract_job_name)
TRANSFORM_JOB=$(terraform output -raw glue_transform_job_name)
LOAD_JOB=$(terraform output -raw glue_load_job_name)

# Run extract job
aws glue start-job-run --job-name $EXTRACT_JOB

# Wait for completion (check in AWS Console or use CLI)
aws glue get-job-run --job-name $EXTRACT_JOB --run-id <RUN_ID>

# Run transform job
aws glue start-job-run --job-name $TRANSFORM_JOB

# Run load job
aws glue start-job-run --job-name $LOAD_JOB
```

### Step 4: Query with Athena

```bash
# Open Athena console
# Use workgroup from Terraform output
WORKGROUP=$(terraform output -raw athena_workgroup_name)
DATABASE=$(terraform output -raw glue_database_name)

# Run queries from athena/queries.sql
```

### Step 5: Setup QuickSight

Follow the guide in `quicksight/setup.md`

---

## Option B: AWS Console Deployment

### Step 1: Create S3 Bucket

1. Go to [S3 Console](https://console.aws.amazon.com/s3/)
2. Click "Create bucket"
3. Bucket name: `uber-etl-pipeline-<your-account-id>`
4. Region: `us-east-1` (or your preferred region)
5. Enable versioning and encryption
6. Click "Create bucket"

### Step 2: Upload Data and Scripts

1. Upload `uber_data.csv` to `s3://bucket-name/raw-data/`
2. Upload Glue scripts:
   - `glue/extract_job.py` → `s3://bucket-name/scripts/glue-jobs/`
   - `glue/transform_job.py` → `s3://bucket-name/scripts/glue-jobs/`
   - `glue/load_job.py` → `s3://bucket-name/scripts/glue-jobs/`

### Step 3: Create IAM Role for Glue

1. Go to [IAM Console](https://console.aws.amazon.com/iam/)
2. Click "Roles" → "Create role"
3. Service: AWS Glue
4. Attach policies:
   - `AWSGlueServiceRole`
   - Custom S3 policy (see terraform/main.tf for reference)
5. Role name: `uber-etl-glue-role`

### Step 4: Create Glue Database

1. Go to [Glue Console](https://console.aws.amazon.com/glue/)
2. Click "Databases" → "Add database"
3. Name: `uber_data_db`

### Step 5: Create Glue Jobs

For each job (extract, transform, load):

1. Go to Glue Console → "ETL jobs" → "Script editor"
2. Choose "Spark"
3. Upload script from S3
4. Configure:
   - IAM role: `uber-etl-glue-role`
   - Glue version: 4.0
   - Worker type: G.1X
   - Number of workers: 2
5. Add job parameters (see terraform/main.tf)
6. Save and run

### Step 6: Create Athena Workgroup

1. Go to [Athena Console](https://console.aws.amazon.com/athena/)
2. Click "Workgroups" → "Create workgroup"
3. Name: `uber-analytics`
4. Query result location: `s3://bucket-name/athena-results/`
5. Enable encryption

### Step 7: Run Queries

1. Switch to `uber-analytics` workgroup
2. Select database: `uber_data_db`
3. Run queries from `athena/queries.sql`

### Step 8: Setup QuickSight

Follow `quicksight/setup.md`

---

## Option C: AWS CLI Deployment

### Step 1: Set Variables

```bash
export AWS_REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export BUCKET_NAME="uber-etl-pipeline-${ACCOUNT_ID}"
export PROJECT_NAME="uber-etl-pipeline"
```

### Step 2: Create S3 Bucket

```bash
# Create bucket
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### Step 3: Upload Files

```bash
# Upload raw data
aws s3 cp ../data/uber_data.csv s3://$BUCKET_NAME/raw-data/uber_data.csv

# Upload Glue scripts
aws s3 cp glue/extract_job.py s3://$BUCKET_NAME/scripts/glue-jobs/extract_job.py
aws s3 cp glue/transform_job.py s3://$BUCKET_NAME/scripts/glue-jobs/transform_job.py
aws s3 cp glue/load_job.py s3://$BUCKET_NAME/scripts/glue-jobs/load_job.py
```

### Step 4: Create IAM Role

```bash
# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "glue.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Create role
aws iam create-role \
  --role-name ${PROJECT_NAME}-glue-role \
  --assume-role-policy-document file://trust-policy.json

# Attach managed policy
aws iam attach-role-policy \
  --role-name ${PROJECT_NAME}-glue-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

# Create and attach S3 policy (see terraform/main.tf for policy JSON)
```

### Step 5: Create Glue Database

```bash
aws glue create-database \
  --database-input '{
    "Name": "uber_data_db",
    "Description": "Database for Uber ETL pipeline"
  }'
```

### Step 6: Create Glue Jobs

```bash
# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name ${PROJECT_NAME}-glue-role --query 'Role.Arn' --output text)

# Create extract job
aws glue create-job \
  --name ${PROJECT_NAME}-extract-job \
  --role $ROLE_ARN \
  --command '{
    "Name": "glueetl",
    "ScriptLocation": "s3://'$BUCKET_NAME'/scripts/glue-jobs/extract_job.py",
    "PythonVersion": "3"
  }' \
  --default-arguments '{
    "--S3_BUCKET": "'$BUCKET_NAME'",
    "--RAW_DATA_PATH": "raw-data/uber_data.csv",
    "--OUTPUT_PATH": "processed-data/extracted/"
  }' \
  --glue-version "4.0" \
  --number-of-workers 2 \
  --worker-type "G.1X"

# Repeat for transform and load jobs
```

### Step 7: Run Pipeline

```bash
# Run extract job
EXTRACT_RUN_ID=$(aws glue start-job-run \
  --job-name ${PROJECT_NAME}-extract-job \
  --query 'JobRunId' --output text)

echo "Extract job started: $EXTRACT_RUN_ID"

# Monitor job
aws glue get-job-run \
  --job-name ${PROJECT_NAME}-extract-job \
  --run-id $EXTRACT_RUN_ID \
  --query 'JobRun.JobRunState'

# Run transform and load jobs after extract completes
```

---

## Verification

### 1. Check S3 Data

```bash
# List processed data
aws s3 ls s3://$BUCKET_NAME/processed-data/ --recursive

# Should see:
# - datetime_dim/
# - passenger_count_dim/
# - trip_distance_dim/
# - rate_code_dim/
# - pickup_location_dim/
# - dropoff_location_dim/
# - payment_type_dim/
# - fact_table/
```

### 2. Check Glue Catalog

```bash
# List tables
aws glue get-tables --database-name uber_data_db

# Should see all 8 tables
```

### 3. Test Athena Query

```bash
# Run a simple query
aws athena start-query-execution \
  --query-string "SELECT COUNT(*) FROM uber_data_db.fact_table" \
  --result-configuration "OutputLocation=s3://$BUCKET_NAME/athena-results/" \
  --work-group uber-analytics
```

---

## Troubleshooting

### Issue: Glue job fails with "Access Denied"

**Solution**: Check IAM role has S3 permissions
```bash
aws iam get-role-policy --role-name ${PROJECT_NAME}-glue-role --policy-name s3-access
```

### Issue: "Table not found" in Athena

**Solution**: Run the load job to register tables in Glue Catalog
```bash
aws glue start-job-run --job-name ${PROJECT_NAME}-load-job
```

### Issue: Glue job timeout

**Solution**: Increase timeout or reduce data size
```bash
aws glue update-job --job-name ${PROJECT_NAME}-extract-job --timeout 120
```

### Issue: High Athena costs

**Solution**: 
- Use partitioned tables
- Limit SELECT columns
- Use PARQUET format (already done)

---

## Cost Optimization

1. **Use S3 Lifecycle Policies**
   - Move old data to Glacier after 90 days

2. **Optimize Glue Jobs**
   - Use smaller worker types for small datasets
   - Enable job bookmarks to avoid reprocessing

3. **Athena Best Practices**
   - Partition data by date
   - Use columnar formats (Parquet)
   - Compress data

4. **QuickSight**
   - Use SPICE for better performance
   - Schedule refreshes during off-peak hours

---

## Next Steps

1. **Automate Pipeline**
   - Use AWS Step Functions or EventBridge
   - Schedule daily runs

2. **Add Monitoring**
   - CloudWatch alarms for job failures
   - SNS notifications

3. **Data Quality**
   - Add Glue Data Quality rules
   - Implement data validation

4. **Security**
   - Enable S3 bucket logging
   - Use KMS encryption
   - Implement least privilege IAM

---

## Clean Up

To delete all resources:

### Terraform
```bash
cd terraform
terraform destroy
```

### Manual
```bash
# Delete S3 bucket (must be empty first)
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# Delete Glue jobs
aws glue delete-job --job-name ${PROJECT_NAME}-extract-job
aws glue delete-job --job-name ${PROJECT_NAME}-transform-job
aws glue delete-job --job-name ${PROJECT_NAME}-load-job

# Delete Glue database
aws glue delete-database --name uber_data_db

# Delete IAM role
aws iam delete-role --role-name ${PROJECT_NAME}-glue-role
```

---

## Support

For issues or questions:
- Check AWS Glue logs in CloudWatch
- Review Athena query history
- Consult AWS documentation
