# --- iam.tf ---

# ----------------------------------------------------------------
# 1. IAM Role & Policy for "Presigned URL Generator" Lambda
# ----------------------------------------------------------------
resource "aws_iam_role" "presigned_url_lambda_role" {
  name = var.presigned_url_lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_policy" "presigned_url_lambda_policy" {
  name        = var.presigned_url_lambda_policy_name
  description = "IAM policy for Presigned URL Lambda to allow s3:PutObject and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["arn:aws:s3:::${var.upload_bucket_name}/*"]
      }
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "presigned_url_lambda_attachment" {
  role       = aws_iam_role.presigned_url_lambda_role.name
  policy_arn = aws_iam_policy.presigned_url_lambda_policy.arn
}


# ----------------------------------------------------------------
# 2. IAM Role & Policy for "Save Metadata" Lambda
# ----------------------------------------------------------------
resource "aws_iam_role" "save_metadata_lambda_role" {
  name = var.save_metadata_lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_policy" "save_metadata_lambda_policy" {
  name        = var.save_metadata_lambda_policy_name
  description = "IAM policy for Save Metadata Lambda to write to DynamoDB and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.metadata_table.arn
      }
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "save_metadata_lambda_attachment" {
  role       = aws_iam_role.save_metadata_lambda_role.name
  policy_arn = aws_iam_policy.save_metadata_lambda_policy.arn
}


# ----------------------------------------------------------------
# 3. IAM Role & Policy for "List Files" Lambda
# ----------------------------------------------------------------
resource "aws_iam_role" "list_files_lambda_role" {
  name = var.list_files_lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_policy" "list_files_lambda_policy" {
  name        = var.list_files_lambda_policy_name
  description = "IAM policy for List Files Lambda to scan DynamoDB and write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:Scan"]
        Resource = aws_dynamodb_table.metadata_table.arn
      }
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "list_files_lambda_attachment" {
  role       = aws_iam_role.list_files_lambda_role.name
  policy_arn = aws_iam_policy.list_files_lambda_policy.arn
}