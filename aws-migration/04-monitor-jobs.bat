@echo off
REM Batch Script for CMD - Monitor Glue Jobs
REM Region: ap-southeast-1

set REGION=ap-southeast-1
set LOG_FILE=job_status.log

echo ========================================
echo Monitoring Glue Jobs
echo ========================================
echo.

echo Monitoring jobs... (Press Ctrl+C to stop)
echo.

:LOOP
cls
echo ========================================
echo   Timestamp: %DATE% %TIME%
echo ========================================
echo.

REM Check Extract Job
for /f "tokens=*" %%a in ('aws glue get-job-runs --job-name uber-etl-extract-job --max-results 1 --query "JobRuns[0].JobRunState" --output text --region %REGION%') do set EXTRACT_STATUS=%%a
echo [Extract Job]   Status: %EXTRACT_STATUS%

REM Check Transform Job
for /f "tokens=*" %%a in ('aws glue get-job-runs --job-name uber-etl-transform-job --max-results 1 --query "JobRuns[0].JobRunState" --output text --region %REGION%') do set TRANSFORM_STATUS=%%a
echo [Transform Job] Status: %TRANSFORM_STATUS%

REM Check Load Job
for /f "tokens=*" %%a in ('aws glue get-job-runs --job-name uber-etl-load-job --max-results 1 --query "JobRuns[0].JobRunState" --output text --region %REGION%') do set LOAD_STATUS=%%a
echo [Load Job]      Status: %LOAD_STATUS%

echo.
echo ========================================
echo Last 5 CloudWatch Logs (Extract Job):
aws logs get-log-events --log-group-name /aws-glue/jobs/output --log-stream-name uber-etl-extract-job --limit 5 --query "events[*].message" --output text --region %REGION% 2>nul
echo.

echo Refreshing in 10 seconds...
timeout /t 10 >nul
goto LOOP
