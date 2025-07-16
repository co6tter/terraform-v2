terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region
}

# 一意なバケット名を自動生成
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  bucket_name_effective = "${var.bucket_name_prefix}-${random_string.suffix.result}"
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name_effective
}
