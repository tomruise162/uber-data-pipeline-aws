# Terraform Variables

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "uber-etl-pipeline"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "glue_database_name" {
  description = "Name of the Glue catalog database"
  type        = string
  default     = "uber_data_db"
}

variable "glue_worker_type" {
  description = "Glue worker type (G.1X, G.2X, G.025X)"
  type        = string
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Number of Glue workers"
  type        = number
  default     = 2
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
