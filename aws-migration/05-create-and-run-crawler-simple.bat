@echo off
REM Batch Script for CMD - Create and Run Glue Crawler (Simple Version)
REM This version creates 1 crawler pointing to processed-data/ root
REM Region: ap-southeast-1

set BUCKET_NAME=uber-data-v1
set REGION=ap-southeast-1
set CRAWLER_NAME=uber-etl-crawler
set DATABASE_NAME=uber_data_db

echo ========================================
echo Creating Glue Crawler (Simple Version)
echo ========================================
echo.
echo [NOTE] This creates 1 crawler pointing to processed-data/ root
echo   - Will crawl all subfolders and create tables automatically
echo   - Alternative to 05-create-glue-crawler.bat (which uses 2 separate crawlers)
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

REM Check if crawler exists
aws glue get-crawler --name %CRAWLER_NAME% --region %REGION% >nul 2>&1
if errorlevel 1 (
    echo Crawler does not exist. Creating %CRAWLER_NAME%...
    
    REM Create crawler pointing to processed-data/ root
    aws glue create-crawler ^
        --name %CRAWLER_NAME% ^
        --role %ROLE_ARN% ^
        --database-name %DATABASE_NAME% ^
        --targets "{\"S3Targets\":[{\"Path\":\"s3://%BUCKET_NAME%/processed-data/\"}]}" ^
        --table-prefix "" ^
        --description "Crawler for all processed data (extracted + dim + fact tables)" ^
        --region %REGION%
    
    if errorlevel 1 (
        echo [ERROR] Failed to create crawler
        pause
        exit /b 1
    )
    echo [OK] Crawler created
) else (
    echo [INFO] Crawler already exists, skipping creation
)

REM Start crawler
echo.
echo Starting crawler...
aws glue start-crawler --name %CRAWLER_NAME% --region %REGION%
if errorlevel 1 (
    echo [WARNING] Crawler might already be running, checking status...
) else (
    echo [OK] Crawler started
)

REM Wait for crawler
echo.
echo Monitoring crawler status...
echo.

:LOOP
for /f "tokens=*" %%a in ('aws glue get-crawler --name %CRAWLER_NAME% --query "Crawler.State" --output text --region %REGION% 2^>nul') do set STATE=%%a

if "%STATE%"=="" (
    echo [ERROR] Cannot get crawler status
    pause
    exit /b 1
)

echo Crawler Status: %STATE%

if "%STATE%"=="READY" (
    echo.
    echo [SUCCESS] Crawler finished!
    goto SHOW_TABLES
)

if "%STATE%"=="FAILED" (
    echo [ERROR] Crawler failed!
    pause
    exit /b 1
)

timeout /t 5 >nul
goto LOOP

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
echo 3. Run queries from 06-run-athena-queries.sql
echo.
echo ========================================
echo.

pause
exit /b 0

