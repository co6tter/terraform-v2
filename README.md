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

## Note

- sample
