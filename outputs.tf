# --- outputs.tf ---

# ----------------------------------------------------------------
# API Gateway
# ----------------------------------------------------------------
output "api_endpoint" {
  description = "The invoke URL for the API Gateway stage"
  value       = aws_apigatewayv2_stage.default_stage.invoke_url
}

# ----------------------------------------------------------------
# S3
# ----------------------------------------------------------------
output "upload_bucket_name" {
  description = "The name of the S3 bucket for uploads"
  value       = aws_s3_bucket.upload_bucket.id
}
output "upload_bucket_arn" {
  description = "The ARN of the S3 bucket for uploads"
  value       = aws_s3_bucket.upload_bucket.arn
}

# ----------------------------------------------------------------
# DynamoDB
# ----------------------------------------------------------------
output "metadata_table_name" {
  description = "The name of the DynamoDB metadata table"
  value       = aws_dynamodb_table.metadata_table.name
}
output "metadata_table_arn" {
  description = "The ARN of the DynamoDB metadata table"
  value       = aws_dynamodb_table.metadata_table.arn
}

# ----------------------------------------------------------------
# IAM & Lambda for Presigned URL
# ----------------------------------------------------------------
output "presigned_url_lambda_role_arn" {
  description = "The ARN of the Presigned URL Lambda execution role"
  value       = aws_iam_role.presigned_url_lambda_role.arn
}
output "deployed_presigned_url_lambda_arn" {
  description = "The ARN of the deployed Presigned URL Lambda function"
  value       = aws_lambda_function.presigned_url_lambda.arn
}

# ----------------------------------------------------------------
# IAM & Lambda for Save Metadata
# ----------------------------------------------------------------
output "save_metadata_lambda_role_arn" {
  description = "The ARN of the Save Metadata Lambda execution role"
  value       = aws_iam_role.save_metadata_lambda_role.arn
}
output "deployed_save_metadata_lambda_arn" {
  description = "The ARN of the deployed Save Metadata Lambda function"
  value       = aws_lambda_function.save_metadata_lambda.arn
}

# ----------------------------------------------------------------
# IAM & Lambda for List Files
# ----------------------------------------------------------------
output "list_files_lambda_role_arn" {
  description = "The ARN of the List Files Lambda execution role"
  value       = aws_iam_role.list_files_lambda_role.arn
}
output "deployed_list_files_lambda_arn" {
  description = "The ARN of the deployed List Files Lambda function"
  value       = aws_lambda_function.list_files_lambda.arn
}