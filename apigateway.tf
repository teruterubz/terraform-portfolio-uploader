# --- apigateway.tf ---

# ----------------------------------------------------------------
# 1. API Gateway (HTTP API) 本体
# ----------------------------------------------------------------
resource "aws_apigatewayv2_api" "uploader_api" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = "API for the File Uploader portfolio project"

  cors_configuration {
    allow_origins = ["*"] # 本番ではフロントエンドのドメインを指定
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = var.common_tags
}

# ----------------------------------------------------------------
# 2. API Gateway ステージ
# ----------------------------------------------------------------
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.uploader_api.id
  name        = var.api_stage_name # $default
  auto_deploy = true

  tags = var.common_tags
}

# ----------------------------------------------------------------
# 3. Integration & Route for "Presigned URL" Lambda
# ----------------------------------------------------------------
resource "aws_apigatewayv2_integration" "lambda_presigned_url_integration" {
  api_id                 = aws_apigatewayv2_api.uploader_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.presigned_url_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "presigned_url_route" {
  api_id    = aws_apigatewayv2_api.uploader_api.id
  route_key = "POST /generate-presigned-url" # 変数化も可能だが、ここでは直接記述
  target    = "integrations/${aws_apigatewayv2_integration.lambda_presigned_url_integration.id}"
}

# ----------------------------------------------------------------
# 4. Integration & Route for "List Files" Lambda
# ----------------------------------------------------------------
resource "aws_apigatewayv2_integration" "lambda_list_files_integration" {
  api_id                 = aws_apigatewayv2_api.uploader_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list_files_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_files_route" {
  api_id    = aws_apigatewayv2_api.uploader_api.id
  route_key = var.list_files_api_route_key # こちらは変数を使用
  target    = "integrations/${aws_apigatewayv2_integration.lambda_list_files_integration.id}"
}