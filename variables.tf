# --- variables.tf ---

variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "ap-northeast-1"
}

variable "lambda_role_name" {
  type        = string
  description = "Name for the Lambda execution IAM role"
  # 値は terraform.tfvars から読み込みます
}

variable "lambda_policy_name" {
  type        = string
  description = "Name for the IAM policy granting Lambda basic execution rights"
  # 値は terraform.tfvars から読み込みます
}

variable "upload_bucket_name" {
  type        = string
  description = "Name for the S3 bucket to upload files to (must be globally unique)"
  # 値は terraform.tfvars から読み込みます
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to resources"
  default = {
    Environment = "Practice-Upload-Infra" # タグの値を更新
    ManagedBy   = "Terraform"
  }
}

# --- variables.tf に追記 ---

variable "lambda_function_name" {
  type        = string
  description = "Name for the Lambda function (e.g., for presigned URL generation)"
  # default値は設定せず、値は terraform.tfvars から読み込みます
}

# --- variables.tf に以下を追記 ---

variable "api_name" {
  type        = string
  description = "Name for the API Gateway HTTP API"
}

variable "api_stage_name" {
  type        = string
  description = "Name for the API Gateway stage (e.g., $default or dev)"
  default     = "$default" # デフォルトステージは自動デプロイされ便利
}

variable "api_route_key" {
  type        = string
  description = "Route key for the API Gateway (e.g., 'POST /generate-presigned-url')"
}


# --- variables.tf に以下を追記（既にあれば確認のみ） ---

variable "dynamodb_table_name" {
  type        = string
  description = "The name of the DynamoDB table for file metadata"
}

variable "dynamodb_hash_key" {
  type        = string
  description = "The name of the partition key (hash key) for the DynamoDB table"
}

# --- variables.tf に以下を追記 ---

variable "save_metadata_lambda_role_name" {
  type        = string
  description = "Name for the IAM role for the 'Save Metadata' Lambda function"
}

variable "save_metadata_lambda_policy_name" {
  type        = string
  description = "Name for the IAM policy for the 'Save Metadata' Lambda function"
}


# --- variables.tf に以下を追記 ---

variable "save_metadata_lambda_function_name" {
  type        = string
  description = "Name for the 'Save Metadata' Lambda function"
}
# --- variables.tf に以下を追記 ---

variable "list_files_lambda_role_name" {
  type        = string
  description = "Name for the IAM role for the 'List Files' Lambda function"
}

variable "list_files_lambda_policy_name" {
  type        = string
  description = "Name for the IAM policy for the 'List Files' Lambda function"
}
# --- variables.tf に以下を追記 ---

variable "list_files_lambda_function_name" {
  type        = string
  description = "Name for the 'List Files' Lambda function"
}

variable "list_files_api_route_key" {
  type        = string
  description = "Route key for the List Files API endpoint (e.g., 'GET /files')"
  default     = "GET /files"
}