# --- lambda.tf ---

# ----------------------------------------------------------------
# 1. "Presigned URL Generator" Lambda
# ----------------------------------------------------------------
data "archive_file" "presigned_url_lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "presigned_url_lambda_package.zip"
}

resource "aws_lambda_function" "presigned_url_lambda" {
  function_name = var.presigned_url_lambda_name
  role          = aws_iam_role.presigned_url_lambda_role.arn # iam.tfで定義したロールを参照
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  filename         = data.archive_file.presigned_url_lambda_zip.output_path
  source_code_hash = data.archive_file.presigned_url_lambda_zip.output_base64sha256

  environment {
    variables = {
      S3_BUCKET_NAME = var.upload_bucket_name
    }
  }
  tags = var.common_tags
}

# ----------------------------------------------------------------
# 2. "Save Metadata" Lambda
# ----------------------------------------------------------------
data "archive_file" "save_metadata_lambda_zip" {
  type        = "zip"
  source_file = "save_metadata_lambda.py"
  output_path = "save_metadata_lambda_package.zip"
}

resource "aws_lambda_function" "save_metadata_lambda" {
  function_name = var.save_metadata_lambda_name
  role          = aws_iam_role.save_metadata_lambda_role.arn # iam.tfで定義したロールを参照
  handler       = "save_metadata_lambda.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  filename         = data.archive_file.save_metadata_lambda_zip.output_path
  source_code_hash = data.archive_file.save_metadata_lambda_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }
  tags = var.common_tags
}

# ----------------------------------------------------------------
# 3. "List Files" Lambda
# ----------------------------------------------------------------
data "archive_file" "list_files_lambda_zip" {
  type        = "zip"
  source_file = "list_files_lambda.py"
  output_path = "list_files_lambda_package.zip"
}

resource "aws_lambda_function" "list_files_lambda" {
  function_name = var.list_files_lambda_name
  role          = aws_iam_role.list_files_lambda_role.arn # iam.tfで定義したロールを参照
  handler       = "list_files_lambda.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  filename         = data.archive_file.list_files_lambda_zip.output_path
  source_code_hash = data.archive_file.list_files_lambda_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }
  tags = var.common_tags
}

# ----------------------------------------------------------------
# 4. Lambda Permissions
# ----------------------------------------------------------------
# S3サービスが「メタデータ保存Lambda」を呼び出すための権限
resource "aws_lambda_permission" "allow_s3_invoke_save_metadata_lambda" {
  statement_id  = "AllowS3InvokeSaveMetadataLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.save_metadata_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload_bucket.arn
}

# API Gateway が「署名付きURL生成Lambda」を呼び出すための権限
resource "aws_lambda_permission" "api_gw_invoke_presigned_url_lambda" {
  statement_id  = "AllowAPIGatewayInvokePresignedUrl"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.uploader_api.execution_arn}/*/${split(" ", var.api_route_key)[0]}${split(" ", var.api_route_key)[1]}" # POST /generate-presigned-url
}

# API Gateway が「ファイル一覧取得Lambda」を呼び出すための権限
resource "aws_lambda_permission" "api_gw_invoke_list_files_lambda" {
  statement_id  = "AllowAPIGatewayInvokeListFiles"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_files_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.uploader_api.execution_arn}/*/${split(" ", var.list_files_api_route_key)[0]}${split(" ", var.list_files_api_route_key)[1]}" # GET /files
}