# --- main.tf ---

provider "aws" {
  region = var.aws_region
}

# --- IAM Role & Policy (既存の定義をベースにS3権限を追加) ---
resource "aws_iam_role" "lambda_exec_role" {
  name = var.lambda_role_name
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

resource "aws_iam_policy" "lambda_logging_policy" {
  name        = var.lambda_policy_name
  description = "IAM policy for Lambda basic execution and S3 PutObject for presigned URLs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logsへの基本的な書き込み操作
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # S3へのPutObject権限 (署名付きURL生成のため)
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.upload_bucket_name}",
          "arn:aws:s3:::${var.upload_bucket_name}/*"
        ]
      }
    ]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

# --- S3バケット (アップロード用) の定義 ---
resource "aws_s3_bucket" "upload_bucket" {
  bucket = var.upload_bucket_name # 変数でバケット名を指定
  tags   = var.common_tags

  # CORS設定 (ブラウザからの直接アップロードに必要になる)
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"] # 本番ではフロントエンドのドメインを指定
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# --- Outputs ---
output "lambda_role_arn" {
  description = "The ARN of the created Lambda execution role"
  value       = aws_iam_role.lambda_exec_role.arn
}

output "lambda_policy_arn" {
  description = "The ARN of the created Lambda logging policy"
  value       = aws_iam_policy.lambda_logging_policy.arn
}

# --- main.tf の末尾の output "upload_bucket_arn" を以下に修正 ---
output "upload_bucket_arn" {
  description = "The ARN of the S3 bucket for uploads"
  value       = aws_s3_bucket.upload_bucket.arn # ★正しくはこちらです！
}

output "upload_bucket_name_output" { # output名を変更 (以前のs3_bucket_nameとかぶらないように)
  description = "The name of the S3 bucket for uploads"
  value       = aws_s3_bucket.upload_bucket.id
}
# --- main.tf に以下を追記 (S3バケット定義の後、Outputsの前など) ---

# --- DynamoDB Table (メタデータ保存用) ---
resource "aws_dynamodb_table" "metadata_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST" # オンデマンド課金
  hash_key     = var.dynamodb_hash_key

  attribute {
    name = var.dynamodb_hash_key # パーティションキーの属性名
    type = "S"                   # 型は String (文字列)
  }

  tags = var.common_tags
}

# --- DynamoDB Table Outputs (新規追加) ---
output "metadata_table_name" {
  description = "The name of the DynamoDB metadata table"
  value       = aws_dynamodb_table.metadata_table.name
}

output "metadata_table_arn" {
  description = "The ARN of the DynamoDB metadata table"
  value       = aws_dynamodb_table.metadata_table.arn
}
# --- main.tf に以下を追記 ---

# 4. Pythonコードをzip化するためのデータソース
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"          # lambda_function.py が main.tf と同じディレクトリにあることを確認
  output_path = "lambda_function_package.zip" # 生成されるzipファイルの名前 (ローカルにも一時的に作成される)
}

# 5. Lambda関数の作成
resource "aws_lambda_function" "presigned_url_lambda" {
  function_name = var.lambda_function_name          # variables.tf で宣言し、terraform.tfvars で設定した関数名
  role          = aws_iam_role.lambda_exec_role.arn # 既存のIAMロールのARNを指定
  handler       = "lambda_function.lambda_handler"  # "Pythonファイル名(拡張子なし).ハンドラー関数名"
  runtime       = "python3.11"                      # Pythonのランタイム (例: python3.9, python3.10, python3.11, python3.12 など。お使いの環境やコードに合わせて)
  timeout       = 30                                # タイムアウト（秒）

  filename         = data.archive_file.lambda_zip.output_path         # 上で作成したzipファイルのパス
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 # コードが変更されたことをTerraformが検知するために必要

  # Lambda関数内で使う環境変数を設定
  environment {
    variables = {
      # Pythonコード内で os.environ.get('S3_BUCKET_NAME') で参照するバケット名
      S3_BUCKET_NAME = var.upload_bucket_name
    }
  }

  tags = var.common_tags # 共通タグ
}

# 作成したLambda関数の情報を出力
output "deployed_lambda_function_name" {
  description = "The name of the deployed Lambda function"
  value       = aws_lambda_function.presigned_url_lambda.function_name
}

output "deployed_lambda_function_arn" {
  description = "The ARN of the deployed Lambda function"
  value       = aws_lambda_function.presigned_url_lambda.arn
}

# --- main.tf に以下を追記 ---

# 6. API Gateway (HTTP API) の作成
resource "aws_apigatewayv2_api" "uploader_api" {
  name          = var.api_name
  protocol_type = "HTTP" # HTTP API を選択
  description   = "API for the File Uploader portfolio project"

  # CORS設定 (ブラウザからの別ドメインアクセスを許可するため)
  # これはAPI Gatewayレベルでの基本的なCORS設定です。
  # より細かいルートごとの設定も可能ですが、まずは全体に適用します。
  cors_configuration {
    allow_origins = ["*"]                             # 本番ではフロントエンドのドメインを指定
    allow_methods = ["POST", "GET", "OPTIONS"]        # Lambdaに繋ぐ予定のメソッド + OPTIONS
    allow_headers = ["Content-Type", "Authorization"] # 必要に応じて追加
    max_age       = 300
  }

  tags = var.common_tags
}

# 7. API Gateway のデフォルトステージ作成
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.uploader_api.id
  name        = var.api_stage_name # $default を使うと、API作成時に自動でデプロイされる
  auto_deploy = true               # ステージへの変更を自動でデプロイ

  # 必要であればアクセスログ設定などもここに追加できるが、今回はシンプルに
  tags = var.common_tags
}

# 8. Lambda関数との統合 (Integration) を作成
resource "aws_apigatewayv2_integration" "lambda_presigned_url_integration" {
  api_id           = aws_apigatewayv2_api.uploader_api.id
  integration_type = "AWS_PROXY" # Lambdaプロキシ統合 (リクエストをそのままLambdaに渡す)
  # integration_uri  = aws_lambda_function.presigned_url_lambda.arn # Lambda関数のARNでもOK
  integration_uri        = aws_lambda_function.presigned_url_lambda.invoke_arn # 推奨はinvoke_arn
  payload_format_version = "2.0"                                               # HTTP APIのLambdaペイロード形式バージョン
}

# 9. ルートの作成 (例: POST /generate-presigned-url が Lambda統合を指すように)
resource "aws_apigatewayv2_route" "presigned_url_route" {
  api_id    = aws_apigatewayv2_api.uploader_api.id
  route_key = var.api_route_key # "POST /generate-presigned-url"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_presigned_url_integration.id}"
}

# 10. API Gateway が Lambda 関数を呼び出すための権限を Lambda 側に追加
resource "aws_lambda_permission" "api_gw_invoke_presigned_url_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url_lambda.function_name # 対象のLambda関数名
  principal     = "apigateway.amazonaws.com"                             # 呼び出し元サービス

  # どのAPI Gatewayのどのルートから呼び出されるかを限定 (セキュリティ向上)
  source_arn = "${aws_apigatewayv2_api.uploader_api.execution_arn}/*/*" # API全体からの呼び出しを許可
  # より具体的に絞るなら: "${aws_apigatewayv2_api.uploader_api.execution_arn}/${var.api_stage_name}/${split(" ", var.api_route_key)[0]}${split(" ", var.api_route_key)[1]}"
}

# 作成したAPI GatewayのエンドポイントURLを出力
output "api_endpoint" {
  description = "The invoke URL for the API Gateway stage"
  value       = aws_apigatewayv2_stage.default_stage.invoke_url
}

# --- main.tf に以下を追記 ---

# --- IAM Role & Policy for SaveMetadata Lambda ---
resource "aws_iam_role" "save_metadata_lambda_role" {
  name = var.save_metadata_lambda_role_name
  assume_role_policy = jsonencode({ # Lambdaサービスがこのロールを引き受けることを許可
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
  description = "IAM policy for SaveMetadata Lambda to write to DynamoDB and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logsへの基本的な書き込み操作
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*" # 全てのログリソースに対して
      },
      {
        # DynamoDBテーブルへの書き込み権限
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
          # 必要に応じて "dynamodb:UpdateItem", "dynamodb:GetItem" なども追加
        ]
        # ★ OutputsからDynamoDBテーブルのARNを参照するように修正！
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

# --- Outputs for new IAM Role & Policy (任意ですが、確認用に便利) ---
output "save_metadata_lambda_role_arn" {
  description = "The ARN of the SaveMetadata Lambda execution role"
  value       = aws_iam_role.save_metadata_lambda_role.arn
}

output "save_metadata_lambda_policy_arn" {
  description = "The ARN of the SaveMetadata Lambda policy"
  value       = aws_iam_policy.save_metadata_lambda_policy.arn
}

# --- main.tf に以下を追記 ---

# --- Save Metadata Lambda Function ---

# Pythonコード(save_metadata_lambda.py)をzip化
data "archive_file" "save_metadata_lambda_zip" {
  type        = "zip"
  source_file = "save_metadata_lambda.py" # この名前のPythonファイルが同じディレクトリにあることを確認
  output_path = "save_metadata_lambda_package.zip"
}

# 「メタデータ保存用」Lambda関数の作成
resource "aws_lambda_function" "save_metadata_lambda" {
  function_name = var.save_metadata_lambda_function_name
  role          = aws_iam_role.save_metadata_lambda_role.arn # ★先ほど作成した新しいIAMロールを指定
  handler       = "save_metadata_lambda.lambda_handler"      # "ファイル名(拡張子なし).関数名"
  runtime       = "python3.11"                               # Pythonランタイム
  timeout       = 30                                         # タイムアウト（秒）

  filename         = data.archive_file.save_metadata_lambda_zip.output_path
  source_code_hash = data.archive_file.save_metadata_lambda_zip.output_base64sha256

  # Lambda関数内で使う環境変数を設定
  environment {
    variables = {
      # Pythonコード内で os.environ.get('DYNAMODB_TABLE_NAME') で参照
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }

  tags = var.common_tags
}

# 作成した「メタデータ保存用Lambda関数」の情報を出力
output "deployed_save_metadata_lambda_name" {
  description = "The name of the deployed Save Metadata Lambda function"
  value       = aws_lambda_function.save_metadata_lambda.function_name
}

output "deployed_save_metadata_lambda_arn" {
  description = "The ARN of the deployed Save Metadata Lambda function"
  value       = aws_lambda_function.save_metadata_lambda.arn
}

# --- main.tf に以下を追記 (SaveMetadata Lambda の Outputs の後など) ---

# --- S3 Event Trigger for SaveMetadata Lambda ---

# 1. S3サービスが「メタデータ保存Lambda」を呼び出すための権限をLambda側に付与
resource "aws_lambda_permission" "allow_s3_invoke_save_metadata_lambda" {
  statement_id  = "AllowS3InvokeSaveMetadataLambda"                      # 権限ステートメントのユニークなID
  action        = "lambda:InvokeFunction"                                # 許可するアクション (Lambda関数の実行)
  function_name = aws_lambda_function.save_metadata_lambda.function_name # 対象のLambda関数
  principal     = "s3.amazonaws.com"                                     # 呼び出し元サービス (S3)
  source_arn    = aws_s3_bucket.upload_bucket.arn                        # どのS3バケットからの呼び出しを許可するか
}

# 2. S3バケット通知設定 (オブジェクト作成時にLambdaをトリガー)
resource "aws_s3_bucket_notification" "upload_bucket_save_metadata_notification" {
  bucket = aws_s3_bucket.upload_bucket.id # 通知を設定するS3バケット

  # 複数の通知設定が可能だが、今回はLambda関数1つ
  lambda_function {
    lambda_function_arn = aws_lambda_function.save_metadata_lambda.arn # 通知先のLambda関数
    events              = ["s3:ObjectCreated:*"]                       # トリガーとするS3イベントタイプ (全てのオブジェクト作成イベント)
    # filter_prefix       = "uploads/" # オプション: 特定のプレフィックス（フォルダ）内のイベントのみを対象にする場合
    # filter_suffix       = ".jpg"     # オプション: 特定のサフィックス（拡張子）のイベントのみを対象にする場合
  }

  # Lambdaへの呼び出し許可(上記のaws_lambda_permission)が先に設定されるように依存関係を指定
  depends_on = [aws_lambda_permission.allow_s3_invoke_save_metadata_lambda]
}

# --- main.tf に以下を追記 ---

# --- IAM Role & Policy for ListFiles Lambda ---
resource "aws_iam_role" "list_files_lambda_role" {
  name = var.list_files_lambda_role_name
  assume_role_policy = jsonencode({ # Lambdaサービスがこのロールを引き受けることを許可
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
  description = "IAM policy for ListFiles Lambda to scan DynamoDB and write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logsへの基本的な書き込み操作
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # DynamoDBテーブルのスキャン権限
        Effect = "Allow"
        Action = [
          "dynamodb:Scan"
        ]
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

# --- Outputs for new IAM Role & Policy ---
output "list_files_lambda_role_arn" {
  description = "The ARN of the ListFiles Lambda execution role"
  value       = aws_iam_role.list_files_lambda_role.arn
}

output "list_files_lambda_policy_arn" {
  description = "The ARN of the ListFiles Lambda policy"
  value       = aws_iam_policy.list_files_lambda_policy.arn
}
# --- main.tf に以下を追記 ---

# --- List Files Lambda Function and API Route ---

# Pythonコード(list_files_lambda.py)をzip化
data "archive_file" "list_files_lambda_zip" {
  type        = "zip"
  source_file = "list_files_lambda.py" # この名前のPythonファイルがあることを確認
  output_path = "list_files_lambda_package.zip"
}

# 「ファイル一覧取得用」Lambda関数の作成
resource "aws_lambda_function" "list_files_lambda" {
  function_name = var.list_files_lambda_function_name
  role          = aws_iam_role.list_files_lambda_role.arn # ★先ほど作成した新しいIAMロールを指定
  handler       = "list_files_lambda.lambda_handler"      # "ファイル名(拡張子なし).関数名"
  runtime       = "python3.11"
  timeout       = 30

  filename         = data.archive_file.list_files_lambda_zip.output_path
  source_code_hash = data.archive_file.list_files_lambda_zip.output_base64sha256

  # Lambda関数内で使う環境変数を設定
  environment {
    variables = {
      # Pythonコード内で os.environ.get('DYNAMODB_TABLE_NAME') で参照
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }

  tags = var.common_tags
}

# 「ファイル一覧取得Lambda」用の新しい統合 (Integration) を作成
resource "aws_apigatewayv2_integration" "lambda_list_files_integration" {
  api_id                 = aws_apigatewayv2_api.uploader_api.id # ★既存のAPI Gatewayを指定
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list_files_lambda.invoke_arn
  payload_format_version = "2.0"
}

# 「ファイル一覧取得」用の新しいルート (Route) を作成
resource "aws_apigatewayv2_route" "list_files_route" {
  api_id    = aws_apigatewayv2_api.uploader_api.id # ★既存のAPI Gatewayを指定
  route_key = var.list_files_api_route_key         # "GET /files"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_list_files_integration.id}"
}

# API Gateway が「ファイル一覧取得Lambda」を呼び出すための権限
resource "aws_lambda_permission" "api_gw_invoke_list_files_lambda" {
  statement_id  = "AllowAPIGatewayInvokeListFiles"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_files_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.uploader_api.execution_arn}/*/${split(" ", var.list_files_api_route_key)[0]}${split(" ", var.list_files_api_route_key)[1]}"
}

# 作成した「ファイル一覧取得Lambda」の情報を出力
output "deployed_list_files_lambda_name" {
  description = "The name of the deployed List Files Lambda function"
  value       = aws_lambda_function.list_files_lambda.function_name
}

output "deployed_list_files_lambda_arn" {
  description = "The ARN of the deployed List Files Lambda function"
  value       = aws_lambda_function.list_files_lambda.arn
}