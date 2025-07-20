resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.bucket_name_prefix}-oac"
  description                       = "OAC for ${aws_s3_bucket.this.bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_function" "security_headers" {
  name    = "${var.bucket_name_prefix}-sec-headers"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var r = event.response;
      var h = r.headers;
      h["strict-transport-security"] = { value: "max-age=31536000; includeSubDomains; preload" };
      h["content-security-policy"] = {
        value: [
          "default-src 'self'",
          "font-src   'self' data:",
          "img-src    'self' data:",
          "object-src 'none'",
          "frame-ancestors 'none'"
        ].join("; ")
      };
      h["x-content-type-options"]    = { value: "nosniff" };
      h["referrer-policy"]           = { value: "strict-origin-when-cross-origin" };
      return r;
    }
  EOT
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
    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.security_headers.arn
    }

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
