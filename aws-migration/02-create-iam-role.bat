@echo off
REM Batch Script for CMD - Create IAM Role
REM Region: ap-southeast-1

set BUCKET_NAME=uber-data-v1
set REGION=ap-southeast-1
set ROLE_NAME=uber-etl-glue-role

echo ========================================
echo Creating IAM Role for Glue
echo ========================================
echo.

REM Create trust policy
echo Creating trust policy...
(
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Effect": "Allow",
echo       "Principal": {
echo         "Service": "glue.amazonaws.com"
echo       },
echo       "Action": "sts:AssumeRole"
echo     }
echo   ]
echo }
) > glue-trust-policy.json

REM Create IAM role
echo Creating IAM role: %ROLE_NAME%
aws iam create-role --role-name %ROLE_NAME% --assume-role-policy-document file://glue-trust-policy.json --description "IAM role for Uber ETL Glue jobs"
if errorlevel 1 (
    echo [WARNING] Role may already exist, continuing...
)

REM Attach AWS managed policy
echo.
echo Attaching AWSGlueServiceRole policy...
aws iam attach-role-policy --role-name %ROLE_NAME% --policy-arn "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
echo [OK] Managed policy attached

REM Create S3 access policy
echo.
echo Creating S3 access policy...
(
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Effect": "Allow",
echo       "Action": [
echo         "s3:GetObject",
echo         "s3:PutObject",
echo         "s3:DeleteObject",
echo         "s3:ListBucket"
echo       ],
echo       "Resource": [
echo         "arn:aws:s3:::%BUCKET_NAME%",
echo         "arn:aws:s3:::%BUCKET_NAME%/*"
echo       ]
echo     }
echo   ]
echo }
) > glue-s3-policy.json

aws iam put-role-policy --role-name %ROLE_NAME% --policy-name "uber-s3-access" --policy-document file://glue-s3-policy.json
echo [OK] S3 access policy attached

REM Create Glue Catalog access policy (required for Crawler and Load job to create tables)
echo.
echo Creating Glue Catalog access policy...
(
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Effect": "Allow",
echo       "Action": [
echo         "glue:CreateTable",
echo         "glue:UpdateTable",
echo         "glue:DeleteTable",
echo         "glue:GetTable",
echo         "glue:GetTables",
echo         "glue:GetDatabase",
echo         "glue:GetDatabases",
echo         "glue:CreateDatabase",
echo         "glue:UpdateDatabase"
echo       ],
echo       "Resource": "*"
echo     }
echo   ]
echo }
) > glue-catalog-policy.json

aws iam put-role-policy --role-name %ROLE_NAME% --policy-name "uber-glue-catalog-access" --policy-document file://glue-catalog-policy.json
echo [OK] Glue Catalog access policy attached

REM Get role ARN
echo.
echo Retrieving role ARN...
for /f "tokens=*" %%a in ('aws iam get-role --role-name %ROLE_NAME% --query "Role.Arn" --output text') do set ROLE_ARN=%%a

echo.
echo ========================================
echo [SUCCESS] IAM Role Created!
echo ========================================
echo.
echo Role ARN: %ROLE_ARN%
echo.

REM Save role ARN
echo %ROLE_ARN% > role-arn.txt
echo Role ARN saved to: role-arn.txt

REM Cleanup
del glue-trust-policy.json
del glue-s3-policy.json
del glue-catalog-policy.json

echo.
echo Next: Run 03-create-glue-jobs.bat
echo.

pause
