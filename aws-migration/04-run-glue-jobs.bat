@echo off
REM Batch Script for CMD - Run Glue Jobs (Extract → Transform)
REM Region: ap-southeast-1

set REGION=ap-southeast-1
set EXTRACT_JOB=uber-etl-extract-job
set TRANSFORM_JOB=uber-etl-transform-job

echo ========================================
echo Running Glue ETL Jobs
echo ========================================
echo.
echo This script will run:
echo   1. Extract Job: %EXTRACT_JOB%
echo   2. Transform Job: %TRANSFORM_JOB%
echo.

REM ========================================
REM Step 1: Run Extract Job
REM ========================================
echo ========================================
echo Step 1: Running Extract Job
echo ========================================
echo.
echo Starting job: %EXTRACT_JOB%
echo This will read raw CSV and write Parquet to processed-data/extracted/
echo.

aws glue start-job-run --job-name %EXTRACT_JOB% --region %REGION%
if errorlevel 1 (
    echo [ERROR] Failed to start extract job
    pause
    exit /b 1
)

echo [OK] Extract job started
echo Waiting for job to complete...
echo.

REM Wait for Extract Job
call :WAIT_FOR_JOB %EXTRACT_JOB%

if errorlevel 1 (
    echo [ERROR] Extract job failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo Step 2: Running Transform Job
echo ========================================
echo.
echo Starting job: %TRANSFORM_JOB%
echo This will read from extracted/ and write 8 tables to processed-data/
echo.

aws glue start-job-run --job-name %TRANSFORM_JOB% --region %REGION%
if errorlevel 1 (
    echo [ERROR] Failed to start transform job
    pause
    exit /b 1
)

echo [OK] Transform job started
echo Waiting for job to complete...
echo.

REM Wait for Transform Job
call :WAIT_FOR_JOB %TRANSFORM_JOB%

if errorlevel 1 (
    echo [ERROR] Transform job failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo [SUCCESS] All Jobs Completed!
echo ========================================
echo.
echo Results:
echo   - processed-data/extracted/*.parquet
echo   - processed-data/datetime_dim/*.parquet
echo   - processed-data/passenger_count_dim/*.parquet
echo   - processed-data/trip_distance_dim/*.parquet
echo   - processed-data/rate_code_dim/*.parquet
echo   - processed-data/pickup_location_dim/*.parquet
echo   - processed-data/dropoff_location_dim/*.parquet
echo   - processed-data/payment_type_dim/*.parquet
echo   - processed-data/fact_table/*.parquet
echo.
echo Next Step: Run 05-create-glue-crawler.bat to create tables in Glue Catalog
echo.

pause
exit /b 0

REM ========================================
REM Function: Wait for job to complete
REM ========================================
:WAIT_FOR_JOB
set JOB_NAME=%1
set MAX_WAIT=1800
set ELAPSED=0

:JOB_LOOP
for /f "tokens=*" %%a in ('aws glue get-job-runs --job-name %JOB_NAME% --max-results 1 --query "JobRuns[0].JobRunState" --output text --region %REGION% 2^>nul') do set JOB_STATE=%%a

if "%JOB_STATE%"=="" (
    echo [WARNING] Cannot get job status
    timeout /t 10 >nul
    set /a ELAPSED+=10
    if %ELAPSED% geq %MAX_WAIT% (
        echo [ERROR] Timeout waiting for job
        exit /b 1
    )
    goto JOB_LOOP
)

echo Job Status: %JOB_STATE%

if "%JOB_STATE%"=="SUCCEEDED" (
    echo [SUCCESS] Job completed successfully!
    exit /b 0
)

if "%JOB_STATE%"=="FAILED" (
    echo [ERROR] Job failed!
    echo Check CloudWatch logs for details
    exit /b 1
)

if "%JOB_STATE%"=="STOPPED" (
    echo [WARNING] Job was stopped
    exit /b 1
)

timeout /t 10 >nul
set /a ELAPSED+=10
if %ELAPSED% geq %MAX_WAIT% (
    echo [ERROR] Timeout waiting for job (30 minutes)
    exit /b 1
)

goto JOB_LOOP

