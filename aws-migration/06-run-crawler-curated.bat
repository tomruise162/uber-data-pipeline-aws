@echo off
REM Batch Script for CMD - Run Curated Crawler Only
REM This script only starts the curated crawler (for 8 dim/fact tables)
REM Use this after running 05-create-glue-crawler.bat for the first time

set REGION=ap-southeast-1
set DATABASE_NAME=uber_data_db
set CRAWLER_CURATED=uber-etl-crawler-curated

echo ========================================
echo Running Curated Crawler
echo ========================================
echo.
echo This will start the crawler for 8 curated tables:
echo   - datetime_dim, passenger_count_dim, trip_distance_dim
echo   - rate_code_dim, pickup_location_dim, dropoff_location_dim
echo   - payment_type_dim, fact_table
echo.

REM Check if crawler exists
aws glue get-crawler --name %CRAWLER_CURATED% --region %REGION% >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Crawler %CRAWLER_CURATED% does not exist
    echo Run 05-create-glue-crawler.bat first to create the crawler
    pause
    exit /b 1
)

echo Starting crawler...
aws glue start-crawler --name %CRAWLER_CURATED% --region %REGION%
if errorlevel 1 (
    echo [WARNING] Crawler might already be running
    echo Checking status...
) else (
    echo [OK] Crawler started
)

REM Wait for crawler
echo.
echo Monitoring crawler status...
echo.

:LOOP
for /f "tokens=*" %%a in ('aws glue get-crawler --name %CRAWLER_CURATED% --query "Crawler.State" --output text --region %REGION%') do set STATE=%%a

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
echo Tables in database %DATABASE_NAME%:
aws glue get-tables --database-name %DATABASE_NAME% --region %REGION% --query "TableList[].Name" --output table

echo.
echo [SUCCESS] Crawler completed!
echo.

pause

