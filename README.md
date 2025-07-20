# terraform-v2

## Setup
```bash
# bootstrap_state.tf作成
terraform init
terraform apply
# backend.tf作成
# bootstrap_state.tfで作成したS3バケット設定
terraform init -migrate-state
# 差分ゼロ確認
terraform plan
```

## Destroy
```bash
terraform state rm aws_s3_bucket.tfstate
terraform destroy -auto-approve
# 復帰
terraform import aws_s3_bucket.tfstate c2-terraform-state-prod
```

## Note

importするときはIDやNameなどリソースによって必要な識別子が異なる。
