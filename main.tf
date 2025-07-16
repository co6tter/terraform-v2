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
  tags = {
    Project = var.bucket_name_prefix
    Env     = "dev"
    Owner   = "c2"
  }
}
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# resource "aws_s3_bucket_versioning" "this" {
#   bucket = aws_s3_bucket.this.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3
    }
  }
}

# resource "aws_kms_key" "s3" {
#   description             = "KMS key for S3 encryption demo"
#   deletion_window_in_days = 7
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "this_kms" {
#   bucket = aws_s3_bucket.this.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = "aws:kms"
#       kms_master_key_id = aws_kms_key.s3.arn
#     }
#   }
# }

# 30日後にバケット内のすべてのオブジェクト（ファイル）が自動削除
# resource "aws_s3_bucket_lifecycle_configuration" "expire_30d" {
#   bucket = aws_s3_bucket.this.id

#   rule {
#     id     = "expire-30d"
#     status = "Enabled"

#     expiration {
#       days = 30
#     }
#   }
# }

# STANDARD → STANDARD_IA → GLACIER → DEEP_ARCHIVE
# 高頻度 低頻度 長期保存 超長期保存
resource "aws_s3_bucket_lifecycle_configuration" "tiering" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "tiering"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 60
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# 他のアカウントからアップロードされたオブジェクトも完全制御
# 意図しないACL設定を防止
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

output "bucket_name" {
  value       = aws_s3_bucket.this.bucket
  description = "作成されたS3バケット名 (ランダムsuffix付)"
}

