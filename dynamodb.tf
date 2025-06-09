# --- dynamodb.tf ---

# --- DynamoDB Table for File Metadata ---
resource "aws_dynamodb_table" "metadata_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST" # オンデマンド課金
  hash_key     = var.dynamodb_hash_key

  attribute {
    name = var.dynamodb_hash_key
    type = "S" # String
  }

  tags = var.common_tags
}