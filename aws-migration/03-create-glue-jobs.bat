@echo off
REM Batch Script for CMD - Create Glue Jobs
REM Region: ap-southeast-1

set BUCKET_NAME=uber-data-v1
set REGION=ap-southeast-1
set DATABASE_NAME=uber_data_db

echo ========================================
echo Creating Glue Database and Jobs
echo ========================================
echo.

REM Get role ARN
if not exist role-arn.txt (
    echo [ERROR] role-arn.txt not found
    echo Run 02-create-iam-role.bat first
    pause
    exit /b 1
)

set /p ROLE_ARN=<role-arn.txt
echo Using IAM Role: %ROLE_ARN%

REM Create Glue Database
echo.
echo Creating Glue database: %DATABASE_NAME%
aws glue create-database --database-input "{\"Name\":\"%DATABASE_NAME%\",\"Description\":\"Database for Uber ETL pipeline data\"}" --region %REGION%
if errorlevel 1 (
    echo [WARNING] Database may already exist, continuing...
) else (
    echo [OK] Database created
)

REM Create Extract Job
echo.
echo Creating Extract Job...
aws glue create-job --name "uber-etl-extract-job" --role %ROLE_ARN% --command "{\"Name\":\"glueetl\",\"ScriptLocation\":\"s3://%BUCKET_NAME%/scripts/glue-jobs/extract_job.py\",\"PythonVersion\":\"3\"}" --default-arguments "{\"--job-language\":\"python\",\"--job-bookmark-option\":\"job-bookmark-disable\",\"--S3_BUCKET\":\"%BUCKET_NAME%\",\"--RAW_DATA_PATH\":\"raw-data/uber_data.csv\",\"--OUTPUT_PATH\":\"processed-data/extracted/\",\"--enable-metrics\":\"true\",\"--enable-spark-ui\":\"true\"}" --glue-version "4.0" --number-of-workers 2 --worker-type "G.1X" --timeout 60 --region %REGION%
if errorlevel 1 (
    echo [WARNING] Job may already exist
) else (
    echo [OK] Extract job created
)

REM Create Transform Job
echo.
echo Creating Transform Job...
aws glue create-job --name "uber-etl-transform-job" --role %ROLE_ARN% --command "{\"Name\":\"glueetl\",\"ScriptLocation\":\"s3://%BUCKET_NAME%/scripts/glue-jobs/transform_job.py\",\"PythonVersion\":\"3\"}" --default-arguments "{\"--job-language\":\"python\",\"--job-bookmark-option\":\"job-bookmark-disable\",\"--S3_BUCKET\":\"%BUCKET_NAME%\",\"--INPUT_PATH\":\"processed-data/extracted/\",\"--OUTPUT_PATH\":\"processed-data/\",\"--enable-metrics\":\"true\",\"--enable-spark-ui\":\"true\"}" --glue-version "4.0" --number-of-workers 2 --worker-type "G.1X" --timeout 60 --region %REGION%
if errorlevel 1 (
    echo [WARNING] Job may already exist
) else (
    echo [OK] Transform job created
)

REM Create Load Job (OPTIONAL - Recommended: Use Crawler instead)
echo.
echo ========================================
echo Load Job (OPTIONAL)
echo ========================================
echo.
echo [NOTE] Load job is OPTIONAL. Recommended approach:
echo   - Use Glue Crawler (05-create-glue-crawler.bat) to create tables
echo   - Crawler is more reliable for Data Lake + Athena workflows
echo.
echo If you still want to create Load job, it will:
echo   - Register tables in Glue Data Catalog using saveAsTable()
echo   - Requires Glue Catalog metastore configuration (already in load_job.py)
echo.
set /p CREATE_LOAD_JOB=Create Load job? (y/N): 
if /i "%CREATE_LOAD_JOB%"=="y" (
    echo Creating Load Job...
    aws glue create-job --name "uber-etl-load-job" --role %ROLE_ARN% --command "{\"Name\":\"glueetl\",\"ScriptLocation\":\"s3://%BUCKET_NAME%/scripts/glue-jobs/load_job.py\",\"PythonVersion\":\"3\"}" --default-arguments "{\"--job-language\":\"python\",\"--job-bookmark-option\":\"job-bookmark-disable\",\"--S3_BUCKET\":\"%BUCKET_NAME%\",\"--INPUT_PATH\":\"processed-data/\",\"--DATABASE_NAME\":\"%DATABASE_NAME%\",\"--enable-metrics\":\"true\",\"--enable-spark-ui\":\"true\"}" --glue-version "4.0" --number-of-workers 2 --worker-type "G.1X" --timeout 60 --region %REGION%
    if errorlevel 1 (
        echo [WARNING] Job may already exist
    ) else (
        echo [OK] Load job created
    )
) else (
    echo [SKIPPED] Load job creation skipped. Use Crawler instead.
)

REM List jobs
echo.
echo Verifying jobs...
aws glue list-jobs --region %REGION% | findstr "uber-etl"

echo.
echo ========================================
echo [SUCCESS] Glue Setup Completed!
echo ========================================
echo.

echo Next Steps:
echo 1. Go to AWS Glue Console:
echo    https://ap-southeast-1.console.aws.amazon.com/glue/
echo.
echo 2. Run ETL jobs in order:
echo    - uber-etl-extract-job
echo    - uber-etl-transform-job
echo    (Load job is optional - see note above)
echo.
echo 3. Create tables in Glue Data Catalog:
echo    RECOMMENDED: Run 05-create-glue-crawler.bat
echo    (This will crawl processed-data/ and create 8 tables)
echo.
echo    ALTERNATIVE: Run uber-etl-load-job (if created above)
echo    (Note: Crawler is more reliable for Athena queries)
echo.
echo 4. Query with Athena after tables are created
echo.

pause
