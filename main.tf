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

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
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


resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    # 他のアカウントからアップロードされたオブジェクトも完全制御
    # 意図しないACL設定を防止
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

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
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

  logging_config {
    bucket          = aws_s3_bucket.cf_logs.bucket_domain_name
    prefix          = "yyyy/MM/dd/"
    include_cookies = false
  }



  default_cache_behavior {
    target_origin_id       = local.cf_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    # マネージドポリシー
    cache_policy_id = data.aws_cloudfront_cache_policy.optimized.id

    # 旧式スタイル
    # クエリもCookieも転送しない (静的コンテンツ向け)
    # forwarded_values {
    #   query_string = false
    #   cookies {
    #     forward = "none"
    #   }
    # }
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

  # カスタムドメイン名（独自ドメイン）では使用できない
  # カスタムドメインを使用したい場合は、代わりにACM証明書やIAM証明書を設定する必要がある
  # viewer_certificate {
  #   cloudfront_default_certificate = true
  # }

  aliases = [var.domain_name]

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate_validation.cert]

  # 403 → error.html (200) を 60 秒キャッシュ
  custom_error_response {
    error_code            = 403
    response_page_path    = "/error.html"
    response_code         = 200
    error_caching_min_ttl = 60
  }

  custom_error_response {
    error_code            = 404
    response_page_path    = "/error.html"
    response_code         = 404
    error_caching_min_ttl = 300
  }

  # 404 → SPA フォールバック (200) を 30 秒キャッシュ
  # custom_error_response {
  #   error_code            = 404
  #   response_page_path    = "/index.html"
  #   response_code         = 200
  #   error_caching_min_ttl = 30
  # }

  # 500 → error.html (500) を 120 秒キャッシュ
  custom_error_response {
    error_code            = 500
    response_page_path    = "/error.html"
    response_code         = 500
    error_caching_min_ttl = 120
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

locals {
  root_domain = trim(var.zone_name, ".")
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.use1
  domain_name       = "*.${local.root_domain}"
  validation_method = "DNS"

  subject_alternative_names = [local.root_domain]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.root.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

data "aws_route53_zone" "root" {
  name         = var.zone_name # 例: example.com.
  private_zone = false
}

resource "aws_route53_record" "cf_alias" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront 固定 Hosted Zone ID
    evaluate_target_health = false
  }
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

