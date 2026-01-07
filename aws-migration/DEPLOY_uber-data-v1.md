# Deployment Script for uber-data-v1 Bucket

## Your Configuration
- **Bucket Name**: `uber-data-v1`
- **Region**: `ap-southeast-1` (Singapore)
- **Bucket URL**: https://ap-southeast-1.console.aws.amazon.com/s3/buckets/uber-data-v1

---

## Step 1: Setup AWS CLI

```bash
# Configure AWS CLI (if not already done)
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: ap-southeast-1
# Default output format: json

# Verify configuration
aws s3 ls s3://uber-data-v1
```

---

## Step 2: Create Folder Structure in S3

```bash
# Set variables
export BUCKET_NAME="uber-data-v1"
export REGION="ap-southeast-1"

# Create folder structure (S3 doesn't have real folders, but we can create prefixes)
aws s3api put-object --bucket $BUCKET_NAME --key raw-data/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/datetime_dim/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/passenger_count_dim/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/trip_distance_dim/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/rate_code_dim/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/pickup_location_dim/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/dropoff_location_dim/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/payment_type_dim/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/fact_table/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/extracted/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key scripts/glue-jobs/ --region $REGION
aws s3api put-object --bucket $BUCKET_NAME --key athena-results/ --region $REGION

# Verify folder structure
aws s3 ls s3://$BUCKET_NAME/ --recursive
```

---

## Step 3: Upload Raw Data

```bash
# Navigate to project directory
cd d:/DE_project/uber-etl-pipeline-data-engineering-project

# Upload the CSV file
aws s3 cp data/uber_data.csv s3://$BUCKET_NAME/raw-data/uber_data.csv --region $REGION

# Verify upload
aws s3 ls s3://$BUCKET_NAME/raw-data/
# Should show: uber_data.csv
```

---

## Step 4: Upload Glue Scripts

```bash
# Upload all Glue job scripts
aws s3 cp aws-migration/glue/extract_job.py s3://$BUCKET_NAME/scripts/glue-jobs/extract_job.py --region $REGION
aws s3 cp aws-migration/glue/transform_job.py s3://$BUCKET_NAME/scripts/glue-jobs/transform_job.py --region $REGION
aws s3 cp aws-migration/glue/load_job.py s3://$BUCKET_NAME/scripts/glue-jobs/load_job.py --region $REGION

# Verify upload
aws s3 ls s3://$BUCKET_NAME/scripts/glue-jobs/
# Should show all 3 Python files
```

---

## Step 5: Create IAM Role for Glue

```bash
# Create trust policy file
cat > glue-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name uber-etl-glue-role \
  --assume-role-policy-document file://glue-trust-policy.json \
  --region $REGION

# Attach AWS managed policy for Glue
aws iam attach-role-policy \
  --role-name uber-etl-glue-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

# Create S3 access policy
cat > glue-s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::uber-data-v1",
        "arn:aws:s3:::uber-data-v1/*"
      ]
    }
  ]
}
EOF

# Attach S3 policy to role
aws iam put-role-policy \
  --role-name uber-etl-glue-role \
  --policy-name uber-s3-access \
  --policy-document file://glue-s3-policy.json

# Get role ARN (save this for later)
aws iam get-role --role-name uber-etl-glue-role --query 'Role.Arn' --output text
```

---

## Step 6: Create Glue Database

```bash
# Create Glue database
aws glue create-database \
  --database-input '{
    "Name": "uber_data_db",
    "Description": "Database for Uber ETL pipeline data"
  }' \
  --region $REGION

# Verify database creation
aws glue get-database --name uber_data_db --region $REGION
```

---

## Step 7: Create Glue Jobs

```bash
# Get IAM role ARN
ROLE_ARN=$(aws iam get-role --role-name uber-etl-glue-role --query 'Role.Arn' --output text)

# Create Extract Job
aws glue create-job \
  --name uber-etl-extract-job \
  --role $ROLE_ARN \
  --command '{
    "Name": "glueetl",
    "ScriptLocation": "s3://uber-data-v1/scripts/glue-jobs/extract_job.py",
    "PythonVersion": "3"
  }' \
  --default-arguments '{
    "--job-language": "python",
    "--job-bookmark-option": "job-bookmark-disable",
    "--S3_BUCKET": "uber-data-v1",
    "--RAW_DATA_PATH": "raw-data/uber_data.csv",
    "--OUTPUT_PATH": "processed-data/extracted/",
    "--enable-metrics": "true",
    "--enable-spark-ui": "true"
  }' \
  --glue-version "4.0" \
  --number-of-workers 2 \
  --worker-type "G.1X" \
  --timeout 60 \
  --region $REGION

# Create Transform Job
aws glue create-job \
  --name uber-etl-transform-job \
  --role $ROLE_ARN \
  --command '{
    "Name": "glueetl",
    "ScriptLocation": "s3://uber-data-v1/scripts/glue-jobs/transform_job.py",
    "PythonVersion": "3"
  }' \
  --default-arguments '{
    "--job-language": "python",
    "--job-bookmark-option": "job-bookmark-disable",
    "--S3_BUCKET": "uber-data-v1",
    "--INPUT_PATH": "processed-data/extracted/",
    "--OUTPUT_PATH": "processed-data/",
    "--enable-metrics": "true",
    "--enable-spark-ui": "true"
  }' \
  --glue-version "4.0" \
  --number-of-workers 2 \
  --worker-type "G.1X" \
  --timeout 60 \
  --region $REGION

# Create Load Job
aws glue create-job \
  --name uber-etl-load-job \
  --role $ROLE_ARN \
  --command '{
    "Name": "glueetl",
    "ScriptLocation": "s3://uber-data-v1/scripts/glue-jobs/load_job.py",
    "PythonVersion": "3"
  }' \
  --default-arguments '{
    "--job-language": "python",
    "--job-bookmark-option": "job-bookmark-disable",
    "--S3_BUCKET": "uber-data-v1",
    "--INPUT_PATH": "processed-data/",
    "--DATABASE_NAME": "uber_data_db",
    "--enable-metrics": "true",
    "--enable-spark-ui": "true"
  }' \
  --glue-version "4.0" \
  --number-of-workers 2 \
  --worker-type "G.1X" \
  --timeout 60 \
  --region $REGION

# Verify jobs created
aws glue list-jobs --region $REGION
```

---

## Step 8: Run the ETL Pipeline

```bash
# Run Extract Job
echo "Starting Extract Job..."
EXTRACT_RUN_ID=$(aws glue start-job-run \
  --job-name uber-etl-extract-job \
  --region $REGION \
  --query 'JobRunId' --output text)

echo "Extract Job Run ID: $EXTRACT_RUN_ID"

# Monitor extract job (wait for completion)
while true; do
  STATUS=$(aws glue get-job-run \
    --job-name uber-etl-extract-job \
    --run-id $EXTRACT_RUN_ID \
    --region $REGION \
    --query 'JobRun.JobRunState' --output text)
  
  echo "Extract Job Status: $STATUS"
  
  if [ "$STATUS" = "SUCCEEDED" ]; then
    echo "✓ Extract job completed successfully!"
    break
  elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "STOPPED" ]; then
    echo "✗ Extract job failed!"
    exit 1
  fi
  
  sleep 30
done

# Run Transform Job
echo "Starting Transform Job..."
TRANSFORM_RUN_ID=$(aws glue start-job-run \
  --job-name uber-etl-transform-job \
  --region $REGION \
  --query 'JobRunId' --output text)

echo "Transform Job Run ID: $TRANSFORM_RUN_ID"

# Monitor transform job
while true; do
  STATUS=$(aws glue get-job-run \
    --job-name uber-etl-transform-job \
    --run-id $TRANSFORM_RUN_ID \
    --region $REGION \
    --query 'JobRun.JobRunState' --output text)
  
  echo "Transform Job Status: $STATUS"
  
  if [ "$STATUS" = "SUCCEEDED" ]; then
    echo "✓ Transform job completed successfully!"
    break
  elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "STOPPED" ]; then
    echo "✗ Transform job failed!"
    exit 1
  fi
  
  sleep 30
done

# Run Load Job
echo "Starting Load Job..."
LOAD_RUN_ID=$(aws glue start-job-run \
  --job-name uber-etl-load-job \
  --region $REGION \
  --query 'JobRunId' --output text)

echo "Load Job Run ID: $LOAD_RUN_ID"

# Monitor load job
while true; do
  STATUS=$(aws glue get-job-run \
    --job-name uber-etl-load-job \
    --run-id $LOAD_RUN_ID \
    --region $REGION \
    --query 'JobRun.JobRunState' --output text)
  
  echo "Load Job Status: $STATUS"
  
  if [ "$STATUS" = "SUCCEEDED" ]; then
    echo "✓ Load job completed successfully!"
    break
  elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "STOPPED" ]; then
    echo "✗ Load job failed!"
    exit 1
  fi
  
  sleep 30
done

echo ""
echo "=========================================="
echo "✓ ETL Pipeline completed successfully!"
echo "=========================================="
```

---

## Step 9: Create Athena Workgroup

```bash
# Create Athena workgroup
aws athena create-work-group \
  --name uber-analytics \
  --description "Workgroup for Uber data analytics" \
  --configuration '{
    "ResultConfigurationUpdates": {
      "OutputLocation": "s3://uber-data-v1/athena-results/",
      "EncryptionConfiguration": {
        "EncryptionOption": "SSE_S3"
      }
    },
    "EnforceWorkGroupConfiguration": true,
    "PublishCloudWatchMetricsEnabled": true
  }' \
  --region $REGION

echo "✓ Athena workgroup created!"
```

---

## Step 10: Test Athena Query

```bash
# Run a test query
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SELECT COUNT(*) as total_trips FROM uber_data_db.fact_table" \
  --result-configuration "OutputLocation=s3://uber-data-v1/athena-results/" \
  --work-group uber-analytics \
  --region $REGION \
  --query 'QueryExecutionId' --output text)

echo "Query ID: $QUERY_ID"

# Wait for query to complete
sleep 5

# Get query results
aws athena get-query-results \
  --query-execution-id $QUERY_ID \
  --region $REGION

echo "✓ Athena query completed!"
```

---

## Quick Commands Summary

```bash
# Set your configuration
export BUCKET_NAME="uber-data-v1"
export REGION="ap-southeast-1"

# 1. Upload data
aws s3 cp data/uber_data.csv s3://$BUCKET_NAME/raw-data/uber_data.csv

# 2. Upload scripts
aws s3 cp aws-migration/glue/ s3://$BUCKET_NAME/scripts/glue-jobs/ --recursive

# 3. Run pipeline (after creating jobs)
aws glue start-job-run --job-name uber-etl-extract-job --region $REGION
aws glue start-job-run --job-name uber-etl-transform-job --region $REGION
aws glue start-job-run --job-name uber-etl-load-job --region $REGION
```

---

## Verification Checklist

- [ ] S3 bucket has folder structure
- [ ] Raw data uploaded to `raw-data/uber_data.csv`
- [ ] Glue scripts uploaded to `scripts/glue-jobs/`
- [ ] IAM role created with proper permissions
- [ ] Glue database `uber_data_db` created
- [ ] All 3 Glue jobs created
- [ ] Extract job ran successfully
- [ ] Transform job ran successfully
- [ ] Load job ran successfully
- [ ] Data visible in S3 `processed-data/` folders
- [ ] Tables registered in Glue Data Catalog
- [ ] Athena can query the tables

---

## Next Steps

1. **Run the deployment script** above step by step
2. **Monitor jobs** in AWS Glue Console
3. **Query data** in Athena Console
4. **Create dashboards** in QuickSight (optional)

## Troubleshooting

If jobs fail, check CloudWatch logs:
```bash
aws logs tail /aws-glue/jobs/output --follow --region $REGION
```
