# --- s3.tf ---

# --- S3 Bucket for File Uploads ---
resource "aws_s3_bucket" "upload_bucket" {
  bucket = var.upload_bucket_name
  tags   = var.common_tags
}

# --- S3 Bucket Versioning Configuration ---
resource "aws_s3_bucket_versioning" "upload_bucket_versioning" {
  bucket = aws_s3_bucket.upload_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --- S3 Bucket CORS Configuration ---
resource "aws_s3_bucket_cors_configuration" "upload_bucket_cors" {
  bucket = aws_s3_bucket.upload_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"] # 本番ではフロントエンドのドメインを指定
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  depends_on = [
    aws_s3_bucket.upload_bucket
  ]
}