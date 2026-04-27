variable "region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "bucket_name" {
  description = "Terraform ステート保存用 S3 バケット名"
  type        = string
  default     = "c2-terraform-state-prod"
}
