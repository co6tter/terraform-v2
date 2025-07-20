# 一意なバケット名を自動生成
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  bucket_name_effective = "${var.bucket_name_prefix}-${random_string.suffix.result}"
  root_domain           = trim(var.zone_name, ".")
  cf_origin_id          = "s3-origin-${var.bucket_name_prefix}"
}
