# S3 Bucket Setup

## Bucket Structure

We'll create one S3 bucket with the following folder structure:

```
uber-etl-pipeline-<your-account-id>/
├── raw-data/
│   └── uber_data.csv
├── processed-data/
│   ├── datetime_dim/
│   ├── passenger_count_dim/
│   ├── trip_distance_dim/
│   ├── rate_code_dim/
│   ├── pickup_location_dim/
│   ├── dropoff_location_dim/
│   ├── payment_type_dim/
│   └── fact_table/
└── scripts/
    └── glue-jobs/
```

## Create S3 Bucket

### Option 1: AWS Console

1. Go to [S3 Console](https://console.aws.amazon.com/s3/)
2. Click "Create bucket"
3. Bucket name: `uber-etl-pipeline-<your-account-id>` (must be globally unique)
4. Region: Choose your preferred region (e.g., `us-east-1`)
5. Keep default settings for:
   - Block Public Access: **Enabled** (recommended)
   - Versioning: Optional
   - Encryption: Enable server-side encryption
6. Click "Create bucket"

### Option 2: AWS CLI

```bash
# Set your bucket name (replace with your account ID)
BUCKET_NAME="uber-etl-pipeline-123456789012"
REGION="us-east-1"

# Create bucket
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Enable versioning (optional)
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

## Upload Raw Data

```bash
# Upload the CSV file
aws s3 cp ../data/uber_data.csv s3://$BUCKET_NAME/raw-data/uber_data.csv

# Verify upload
aws s3 ls s3://$BUCKET_NAME/raw-data/
```

## Create Folder Structure

```bash
# Create folders (S3 doesn't have real folders, but we can create placeholder objects)
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/datetime_dim/
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/passenger_count_dim/
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/trip_distance_dim/
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/rate_code_dim/
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/pickup_location_dim/
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/dropoff_location_dim/
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/payment_type_dim/
aws s3api put-object --bucket $BUCKET_NAME --key processed-data/fact_table/
aws s3api put-object --bucket $BUCKET_NAME --key scripts/glue-jobs/
```

## Bucket Policy (Optional)

If you need to grant specific permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGlueAccess",
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::uber-etl-pipeline-*/*"
    }
  ]
}
```

## Lifecycle Policy (Optional - Cost Optimization)

To automatically transition old data to cheaper storage:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket $BUCKET_NAME \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "ArchiveOldData",
      "Status": "Enabled",
      "Prefix": "processed-data/",
      "Transitions": [{
        "Days": 90,
        "StorageClass": "GLACIER"
      }]
    }]
  }'
```

## Verify Setup

```bash
# List all objects in bucket
aws s3 ls s3://$BUCKET_NAME --recursive

# Check bucket configuration
aws s3api get-bucket-versioning --bucket $BUCKET_NAME
aws s3api get-bucket-encryption --bucket $BUCKET_NAME
```

## Next Steps

After S3 setup is complete:
1. Create IAM roles for Glue jobs
2. Deploy Glue ETL jobs
3. Run the pipeline
