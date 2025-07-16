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
