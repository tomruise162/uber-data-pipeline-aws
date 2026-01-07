# Terraform Outputs

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.uber_etl_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.uber_etl_bucket.arn
}

output "glue_database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.uber_data_db.name
}

output "glue_extract_job_name" {
  description = "Name of the Glue extract job"
  value       = aws_glue_job.extract_job.name
}

output "glue_transform_job_name" {
  description = "Name of the Glue transform job"
  value       = aws_glue_job.transform_job.name
}

output "glue_load_job_name" {
  description = "Name of the Glue load job"
  value       = aws_glue_job.load_job.name
}

output "glue_workflow_name" {
  description = "Name of the Glue workflow"
  value       = aws_glue_workflow.uber_etl_workflow.name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.uber_analytics.name
}

output "glue_job_role_arn" {
  description = "ARN of the Glue job IAM role"
  value       = aws_iam_role.glue_job_role.arn
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "deployment_instructions" {
  description = "Next steps after Terraform deployment"
  value       = <<-EOT
    Deployment successful! Next steps:
    
    1. Upload raw data:
       aws s3 cp ../data/uber_data.csv s3://${aws_s3_bucket.uber_etl_bucket.id}/raw-data/uber_data.csv
    
    2. Run Glue jobs in order:
       aws glue start-job-run --job-name ${aws_glue_job.extract_job.name}
       aws glue start-job-run --job-name ${aws_glue_job.transform_job.name}
       aws glue start-job-run --job-name ${aws_glue_job.load_job.name}
    
    3. Query with Athena:
       Open Athena console and use workgroup: ${aws_athena_workgroup.uber_analytics.name}
       Database: ${aws_glue_catalog_database.uber_data_db.name}
    
    4. Set up QuickSight:
       Follow the guide in ../quicksight/setup.md
  EOT
}
