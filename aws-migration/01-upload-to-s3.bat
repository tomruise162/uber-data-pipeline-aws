@echo off
REM Batch Script for CMD - Upload to S3
REM Bucket: uber-data-v1, Region: ap-southeast-1

echo ========================================
echo AWS Uber ETL Pipeline Deployment
echo Bucket: uber-data-v1
echo Region: ap-southeast-1
echo ========================================
echo.

REM Set variables
set BUCKET_NAME=uber-data-v1
set REGION=ap-southeast-1
set PROJECT_DIR=d:\DE_project\uber-etl-pipeline-data-engineering-project

REM Check AWS CLI
echo Checking AWS CLI...
aws --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS CLI not found
    echo Download from: https://awscli.amazonaws.com/AWSCLIV2.msi
    pause
    exit /b 1
)
echo [OK] AWS CLI installed

REM Verify credentials
echo.
echo Verifying AWS credentials...
aws sts get-caller-identity --region %REGION% >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS credentials not configured
    echo Run: aws configure
    pause
    exit /b 1
)
echo [OK] Credentials configured

REM Verify bucket
echo.
echo Verifying S3 bucket...
aws s3 ls s3://%BUCKET_NAME% --region %REGION% >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Cannot access bucket %BUCKET_NAME%
    pause
    exit /b 1
)
echo [OK] Bucket accessible

echo.
echo ========================================
echo Step 1: Creating Folder Structure
echo ========================================
echo.

REM Create folders
echo Creating folders in S3...
aws s3api put-object --bucket %BUCKET_NAME% --key raw-data/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/datetime_dim/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/passenger_count_dim/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/trip_distance_dim/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/rate_code_dim/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/pickup_location_dim/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/dropoff_location_dim/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/payment_type_dim/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/fact_table/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key processed-data/extracted/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key scripts/glue-jobs/ --region %REGION%
aws s3api put-object --bucket %BUCKET_NAME% --key athena-results/ --region %REGION%

echo [OK] Folder structure created

echo.
echo ========================================
echo Step 2: Uploading Raw Data
echo ========================================
echo.

set CSV_FILE=%PROJECT_DIR%\data\uber_data.csv
if not exist "%CSV_FILE%" (
    echo [ERROR] File not found: %CSV_FILE%
    pause
    exit /b 1
)

echo Uploading uber_data.csv...
aws s3 cp "%CSV_FILE%" s3://%BUCKET_NAME%/raw-data/uber_data.csv --region %REGION%
if errorlevel 1 (
    echo [ERROR] Failed to upload raw data
    pause
    exit /b 1
)
echo [OK] Raw data uploaded

echo.
echo ========================================
echo Step 3: Uploading Glue Scripts
echo ========================================
echo.

echo Uploading extract_job.py...
aws s3 cp "%PROJECT_DIR%\aws-migration\glue\extract_job.py" s3://%BUCKET_NAME%/scripts/glue-jobs/extract_job.py --region %REGION%

echo Uploading transform_job.py...
aws s3 cp "%PROJECT_DIR%\aws-migration\glue\transform_job.py" s3://%BUCKET_NAME%/scripts/glue-jobs/transform_job.py --region %REGION%

echo Uploading load_job.py...
aws s3 cp "%PROJECT_DIR%\aws-migration\glue\load_job.py" s3://%BUCKET_NAME%/scripts/glue-jobs/load_job.py --region %REGION%

echo [OK] Glue scripts uploaded

echo.
echo ========================================
echo Verification
echo ========================================
echo.

echo Bucket contents:
aws s3 ls s3://%BUCKET_NAME%/ --recursive --human-readable --summarize --region %REGION%

echo.
echo ========================================
echo [SUCCESS] Deployment Completed!
echo ========================================
echo.

echo Next Steps:
echo 1. Create IAM role for Glue (run: 02-create-iam-role.bat)
echo 2. Create Glue database and jobs (run: 03-create-glue-jobs.bat)
echo 3. Run the ETL pipeline (run: 04-run-pipeline.bat)
echo 4. Query with Athena (AWS Console)
echo.

echo View bucket in AWS Console:
echo https://ap-southeast-1.console.aws.amazon.com/s3/buckets/uber-data-v1
echo.

pause
