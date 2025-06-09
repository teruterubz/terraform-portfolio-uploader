# --- variables.tf ---

# -- General --
variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "ap-northeast-1"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to resources"
  default     = {}
}

# -- S3 --
variable "upload_bucket_name" {
  type        = string
  description = "Name for the S3 bucket to upload files to (must be globally unique)"
}

# -- DynamoDB --
variable "dynamodb_table_name" {
  type        = string
  description = "The name of the DynamoDB table for file metadata"
}

variable "dynamodb_hash_key" {
  type        = string
  description = "The name of the partition key (hash key) for the DynamoDB table"
}

# -- IAM --
variable "presigned_url_lambda_role_name" {
  type        = string
  description = "Name for the IAM role for the Presigned URL Lambda"
}
variable "presigned_url_lambda_policy_name" {
  type        = string
  description = "Name for the IAM policy for the Presigned URL Lambda"
}
variable "save_metadata_lambda_role_name" {
  type        = string
  description = "Name for the IAM role for the Save Metadata Lambda"
}
variable "save_metadata_lambda_policy_name" {
  type        = string
  description = "Name for the IAM policy for the Save Metadata Lambda"
}
variable "list_files_lambda_role_name" {
  type        = string
  description = "Name for the IAM role for the List Files Lambda"
}
variable "list_files_lambda_policy_name" {
  type        = string
  description = "Name for the IAM policy for the List Files Lambda"
}

# -- Lambda --
variable "presigned_url_lambda_name" {
  type        = string
  description = "Name for the Presigned URL Lambda function"
}
variable "save_metadata_lambda_name" {
  type        = string
  description = "Name for the Save Metadata Lambda function"
}
variable "list_files_lambda_name" {
  type        = string
  description = "Name for the List Files Lambda function"
}

# -- API Gateway --
variable "api_name" {
  type        = string
  description = "Name for the API Gateway HTTP API"
}
variable "api_stage_name" {
  type        = string
  description = "Name for the API Gateway stage (e.g., $default or dev)"
  default     = "$default"
}
variable "api_route_key" {
  type        = string
  description = "Route key for the Presigned URL API endpoint (e.g., 'POST /generate-presigned-url')"
}
variable "list_files_api_route_key" {
  type        = string
  description = "Route key for the List Files API endpoint (e.g., 'GET /files')"
  default     = "GET /files"
}