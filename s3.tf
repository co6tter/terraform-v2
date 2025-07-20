resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name_effective
  force_destroy = true
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

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    # 他のアカウントからアップロードされたオブジェクトも完全制御
    # 意図しないACL設定を防止
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "this_cf" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.allow_cf.json
}


resource "aws_s3_bucket" "cf_logs" {
  bucket        = "${var.bucket_name_prefix}-cf-logs"
  force_destroy = true
  tags = {
    Project = var.bucket_name_prefix
    Purpose = "cloudfront-logs"
  }
}

resource "aws_s3_bucket_ownership_controls" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_acl" "cf_logs_acl" {
  bucket     = aws_s3_bucket.cf_logs.id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.cf_logs]
}

data "aws_iam_policy_document" "cf_log_write" {
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cf_logs.arn}/*"]

    # LogDelivery は必ずこの ACL を付与
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  policy = data.aws_iam_policy_document.cf_log_write.json
}
