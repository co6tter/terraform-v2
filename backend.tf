terraform {
  backend "s3" {
    bucket       = "c2-terraform-state-prod"
    key          = "global/s3_cf/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
