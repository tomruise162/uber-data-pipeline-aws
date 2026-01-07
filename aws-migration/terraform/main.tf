# Terraform Configuration for Uber ETL Pipeline on AWS
# This creates all necessary AWS resources for the pipeline

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# S3 Bucket for Data Storage
# ============================================================

resource "aws_s3_bucket" "uber_etl_bucket" {
  bucket = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "Uber ETL Pipeline Bucket"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "uber_etl_versioning" {
  bucket = aws_s3_bucket.uber_etl_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "uber_etl_encryption" {
  bucket = aws_s3_bucket.uber_etl_bucket.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "uber_etl_public_access_block" {
  bucket = aws_s3_bucket.uber_etl_bucket.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# IAM Role for Glue Jobs
# ============================================================

resource "aws_iam_role" "glue_job_role" {
  name = "${var.project_name}-glue-job-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name    = "Glue Job Role"
    Project = var.project_name
  }
}

# Attach AWS managed policy for Glue
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom policy for S3 access
resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "${var.project_name}-glue-s3-policy"
  role = aws_iam_role.glue_job_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.uber_etl_bucket.arn,
          "${aws_s3_bucket.uber_etl_bucket.arn}/*"
        ]
      }
    ]
  })
}

# ============================================================
# Glue Database
# ============================================================

resource "aws_glue_catalog_database" "uber_data_db" {
  name        = var.glue_database_name
  description = "Database for Uber ETL pipeline data"
  
  catalog_id = data.aws_caller_identity.current.account_id
}

# ============================================================
# Glue Jobs
# ============================================================

# Upload Glue scripts to S3
resource "aws_s3_object" "extract_script" {
  bucket = aws_s3_bucket.uber_etl_bucket.id
  key    = "scripts/glue-jobs/extract_job.py"
  source = "${path.module}/../glue/extract_job.py"
  etag   = filemd5("${path.module}/../glue/extract_job.py")
}

resource "aws_s3_object" "transform_script" {
  bucket = aws_s3_bucket.uber_etl_bucket.id
  key    = "scripts/glue-jobs/transform_job.py"
  source = "${path.module}/../glue/transform_job.py"
  etag   = filemd5("${path.module}/../glue/transform_job.py")
}

resource "aws_s3_object" "load_script" {
  bucket = aws_s3_bucket.uber_etl_bucket.id
  key    = "scripts/glue-jobs/load_job.py"
  source = "${path.module}/../glue/load_job.py"
  etag   = filemd5("${path.module}/../glue/load_job.py")
}

# Extract Job
resource "aws_glue_job" "extract_job" {
  name     = "${var.project_name}-extract-job"
  role_arn = aws_iam_role.glue_job_role.arn
  
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.uber_etl_bucket.id}/scripts/glue-jobs/extract_job.py"
    python_version  = "3"
  }
  
  default_arguments = {
    "--job-language"        = "python"
    "--job-bookmark-option" = "job-bookmark-disable"
    "--S3_BUCKET"          = aws_s3_bucket.uber_etl_bucket.id
    "--RAW_DATA_PATH"      = "raw-data/uber_data.csv"
    "--OUTPUT_PATH"        = "processed-data/extracted/"
    "--enable-metrics"     = "true"
    "--enable-spark-ui"    = "true"
  }
  
  glue_version      = "4.0"
  max_retries       = 1
  timeout           = 60
  number_of_workers = 2
  worker_type       = "G.1X"
  
  tags = {
    Name    = "Extract Job"
    Project = var.project_name
  }
}

# Transform Job
resource "aws_glue_job" "transform_job" {
  name     = "${var.project_name}-transform-job"
  role_arn = aws_iam_role.glue_job_role.arn
  
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.uber_etl_bucket.id}/scripts/glue-jobs/transform_job.py"
    python_version  = "3"
  }
  
  default_arguments = {
    "--job-language"        = "python"
    "--job-bookmark-option" = "job-bookmark-disable"
    "--S3_BUCKET"          = aws_s3_bucket.uber_etl_bucket.id
    "--INPUT_PATH"         = "processed-data/extracted/"
    "--OUTPUT_PATH"        = "processed-data/"
    "--enable-metrics"     = "true"
    "--enable-spark-ui"    = "true"
  }
  
  glue_version      = "4.0"
  max_retries       = 1
  timeout           = 60
  number_of_workers = 2
  worker_type       = "G.1X"
  
  tags = {
    Name    = "Transform Job"
    Project = var.project_name
  }
}

# Load Job
resource "aws_glue_job" "load_job" {
  name     = "${var.project_name}-load-job"
  role_arn = aws_iam_role.glue_job_role.arn
  
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.uber_etl_bucket.id}/scripts/glue-jobs/load_job.py"
    python_version  = "3"
  }
  
  default_arguments = {
    "--job-language"        = "python"
    "--job-bookmark-option" = "job-bookmark-disable"
    "--S3_BUCKET"          = aws_s3_bucket.uber_etl_bucket.id
    "--INPUT_PATH"         = "processed-data/"
    "--DATABASE_NAME"      = aws_glue_catalog_database.uber_data_db.name
    "--enable-metrics"     = "true"
    "--enable-spark-ui"    = "true"
  }
  
  glue_version      = "4.0"
  max_retries       = 1
  timeout           = 60
  number_of_workers = 2
  worker_type       = "G.1X"
  
  tags = {
    Name    = "Load Job"
    Project = var.project_name
  }
}

# ============================================================
# Glue Workflow (Optional - for orchestration)
# ============================================================

resource "aws_glue_workflow" "uber_etl_workflow" {
  name        = "${var.project_name}-etl-workflow"
  description = "Workflow to orchestrate Uber ETL pipeline"
  
  tags = {
    Name    = "Uber ETL Workflow"
    Project = var.project_name
  }
}

# ============================================================
# Athena Workgroup
# ============================================================

resource "aws_athena_workgroup" "uber_analytics" {
  name        = "${var.project_name}-analytics"
  description = "Workgroup for Uber data analytics queries"
  
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    
    result_configuration {
      output_location = "s3://${aws_s3_bucket.uber_etl_bucket.id}/athena-results/"
      
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
  
  tags = {
    Name    = "Uber Analytics Workgroup"
    Project = var.project_name
  }
}

# ============================================================
# Data Sources
# ============================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
