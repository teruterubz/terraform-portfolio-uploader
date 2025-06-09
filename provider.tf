# --- provider.tf ---

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # バージョンを固定
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2" # バージョンを固定
    }
  }
}

provider "aws" {
  region = var.aws_region
}