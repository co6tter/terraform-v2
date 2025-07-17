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

# Origin Access Control
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.bucket_name_prefix}-oac"
  description                       = "OAC for ${aws_s3_bucket.this.bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  cf_origin_id = "s3-origin-${var.bucket_name_prefix}"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "C2 learn S3+CF"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = local.cf_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = local.cf_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    # クエリもCookieも転送しない (静的コンテンツ向け)
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # 最も安価（北米・ヨーロッパのみ）
  # price_class = "PriceClass_100"
  # 中間価格（北米・ヨーロッパ・アジア・オセアニア）
  # price_class = "PriceClass_200"
  # 最も高価（全世界のエッジロケーション）
  # price_class = "PriceClass_All"
  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "allow_cf" {
  statement {
    sid = "AllowCloudFrontServicePrincipalReadOnly"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this_cf" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.allow_cf.json
}
