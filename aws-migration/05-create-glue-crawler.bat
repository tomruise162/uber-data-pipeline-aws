@echo off
REM Batch Script for CMD - Create and Run Glue Crawler (Idempotent)
REM Region: ap-southeast-1
REM This script creates 2 crawlers:
REM   1. uber-etl-crawler-extracted - for extracted/ folder (optional, for verification)
REM   2. uber-etl-crawler-curated - for 8 dim/fact tables (main)

set BUCKET_NAME=uber-data-v1
set REGION=ap-southeast-1
set DATABASE_NAME=uber_data_db
set CRAWLER_EXTRACTED=uber-etl-crawler-extracted
set CRAWLER_CURATED=uber-etl-crawler-curated

echo ========================================
echo Creating Glue Crawlers (Idempotent)
echo ========================================
echo.
echo [IMPORTANT] This script creates 2 crawlers:
echo   1. %CRAWLER_EXTRACTED% - Crawls extracted/ folder (optional, for verification)
echo   2. %CRAWLER_CURATED% - Crawls 8 dim/fact tables (main, required)
echo.
echo This is the RECOMMENDED way to create tables in Glue Data Catalog.
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
echo.

REM ========================================
REM Crawler 1: For extracted/ folder (optional)
REM ========================================
echo ========================================
echo Step 1: Crawler for extracted/ folder
echo ========================================
echo.

REM Check if crawler exists
aws glue get-crawler --name %CRAWLER_EXTRACTED% --region %REGION% >nul 2>&1
if errorlevel 1 (
    echo Crawler does not exist. Creating %CRAWLER_EXTRACTED%...
    
    REM Create targets JSON for extracted folder
    (
    echo {
    echo   "S3Targets": [
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/extracted/"}
    echo   ]
    echo }
    ) > crawler-extracted-targets.json
    
    aws glue create-crawler ^
        --name %CRAWLER_EXTRACTED% ^
        --role %ROLE_ARN% ^
        --database-name %DATABASE_NAME% ^
        --targets file://crawler-extracted-targets.json ^
        --table-prefix "" ^
        --description "Crawler for extracted data (optional, for verification)" ^
        --region %REGION%
    
    if errorlevel 1 (
        echo [ERROR] Failed to create crawler
        del crawler-extracted-targets.json
        pause
        exit /b 1
    )
    echo [OK] Crawler created
    del crawler-extracted-targets.json
) else (
    echo [INFO] Crawler already exists, skipping creation
)

REM Ask if user wants to run extracted crawler
echo.
set /p RUN_EXTRACTED=Run crawler for extracted/ folder? (y/N - optional): 
if /i "%RUN_EXTRACTED%"=="y" (
    echo Starting crawler %CRAWLER_EXTRACTED%...
    aws glue start-crawler --name %CRAWLER_EXTRACTED% --region %REGION%
    if errorlevel 1 (
        echo [WARNING] Crawler might already be running, checking status...
    ) else (
        echo [OK] Crawler started
    )
    echo Waiting for completion...
    call :WAIT_FOR_CRAWLER %CRAWLER_EXTRACTED%
) else (
    echo [SKIPPED] Extracted crawler skipped
)

REM ========================================
REM Crawler 2: For 8 dim/fact tables (main)
REM ========================================
echo.
echo ========================================
echo Step 2: Crawler for curated tables (MAIN)
echo ========================================
echo.
echo This crawler will create 8 tables:
echo   - datetime_dim, passenger_count_dim, trip_distance_dim
echo   - rate_code_dim, pickup_location_dim, dropoff_location_dim
echo   - payment_type_dim, fact_table
echo.

REM Check if crawler exists
aws glue get-crawler --name %CRAWLER_CURATED% --region %REGION% >nul 2>&1
if errorlevel 1 (
    echo Crawler does not exist. Creating %CRAWLER_CURATED%...
    
    REM Create targets JSON for 8 folders
    (
    echo {
    echo   "S3Targets": [
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/datetime_dim/"},
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/passenger_count_dim/"},
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/trip_distance_dim/"},
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/rate_code_dim/"},
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/pickup_location_dim/"},
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/dropoff_location_dim/"},
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/payment_type_dim/"},
    echo     {"Path": "s3://%BUCKET_NAME%/processed-data/fact_table/"}
    echo   ]
    echo }
    ) > crawler-curated-targets.json
    
    aws glue create-crawler ^
        --name %CRAWLER_CURATED% ^
        --role %ROLE_ARN% ^
        --database-name %DATABASE_NAME% ^
        --targets file://crawler-curated-targets.json ^
        --table-prefix "" ^
        --description "Crawler for curated star schema tables (7 dim + 1 fact)" ^
        --region %REGION%
    
    if errorlevel 1 (
        echo [ERROR] Failed to create crawler
        del crawler-curated-targets.json
        pause
        exit /b 1
    )
    echo [OK] Crawler created
    del crawler-curated-targets.json
) else (
    echo [INFO] Crawler already exists, skipping creation
)

REM Start curated crawler (main one)
echo.
echo Starting crawler %CRAWLER_CURATED%...
aws glue start-crawler --name %CRAWLER_CURATED% --region %REGION%
if errorlevel 1 (
    echo [WARNING] Crawler might already be running, checking status...
) else (
    echo [OK] Crawler started
)

REM Wait for crawler to complete
call :WAIT_FOR_CRAWLER %CRAWLER_CURATED%

REM Show tables
goto SHOW_TABLES

REM ========================================
REM Function: Wait for crawler to complete
REM ========================================
:WAIT_FOR_CRAWLER
set CRAWLER_NAME=%1
echo.
echo Monitoring crawler: %CRAWLER_NAME%
echo.

:LOOP
for /f "tokens=*" %%a in ('aws glue get-crawler --name %CRAWLER_NAME% --query "Crawler.State" --output text --region %REGION% 2^>nul') do set STATE=%%a

if "%STATE%"=="" (
    echo [ERROR] Cannot get crawler status
    goto :eof
)

echo Crawler Status: %STATE%

if "%STATE%"=="READY" (
    echo [SUCCESS] Crawler finished!
    goto :eof
)

if "%STATE%"=="STOPPING" (
    echo Crawler is stopping...
    timeout /t 5 >nul
    goto LOOP
)

if "%STATE%"=="FAILED" (
    echo [ERROR] Crawler failed!
    echo Check CloudWatch logs for details
    goto :eof
)

timeout /t 5 >nul
goto LOOP

REM ========================================
REM Show tables in catalog
REM ========================================
:SHOW_TABLES
echo.
echo ========================================
echo Verifying tables in Glue Data Catalog
echo ========================================
echo.
echo Database: %DATABASE_NAME%
echo.
aws glue get-tables --database-name %DATABASE_NAME% --region %REGION% --query "TableList[].Name" --output table

echo.
echo ========================================
echo [SUCCESS] Crawler Setup Completed!
echo ========================================
echo.
echo You can now query these tables using Amazon Athena:
echo   - Database: %DATABASE_NAME%
echo   - Tables: Check list above
echo.
echo Next Steps:
echo 1. Go to Athena Console:
echo    https://ap-southeast-1.console.aws.amazon.com/athena/
echo.
echo 2. Select database: %DATABASE_NAME%
echo.
echo 3. Run queries like:
echo    SELECT * FROM "%DATABASE_NAME%"."fact_table" LIMIT 10;
echo    SELECT * FROM "%DATABASE_NAME%"."datetime_dim" LIMIT 10;
echo.
echo ========================================
echo.

pause
exit /b 0
