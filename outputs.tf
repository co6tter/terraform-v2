output "bucket_name" {
  value       = aws_s3_bucket.this.bucket
  description = "作成されたS3バケット名 (ランダムsuffix付)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.this.domain_name
  description = "CloudFrontドメイン (アクセスURL)"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.this.id
  description = "CloudFront Distribution ID"
}

output "deploy_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions"
  value       = aws_iam_role.github_deploy.arn
}
