variable "region" {
  description = "デプロイ先AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "bucket_name_prefix" {
  description = "バケット名プレフィックス"
  type        = string
  default     = "c2-learn-s3"
}

variable "zone_name" {
  description = "Route 53 Hosted Zone root"
  type        = string
  default     = "example.com." # 末尾ドット推奨
}

# CloudFront で実際に使う “サブドメイン” (例: cdn.example.com)
variable "domain_name" {
  description = "FQDN shown to users"
  type        = string
  default     = "cdn.example.com"
}

variable "repo" {
  description = "GitHub Repository"
  type        = string
  default     = "owner/repo"
}

variable "basic_auth_username" {
  description = "Basic Auth username"
  type        = string
  sensitive   = true
}

variable "basic_auth_password" {
  description = "Basic Auth password"
  type        = string
  sensitive   = true
}

