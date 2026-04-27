# terraform-v2

## Overview

AWS 上に S3 + CloudFront による静的サイトホスティング環境を構築する Terraform コードです。カスタムドメイン（Route 53 / ACM）、CloudFront Functions による Basic 認証・セキュリティヘッダー付与、S3 バックエンドによる状態管理を含みます。個人学習用のインフラ構成として設計されています。

## Tech Stack

- **Terraform** >= 1.6.0（`.tool-versions` では 1.14.9 を使用）
- **AWS Provider** ~> 6.0
- **Random Provider** ~> 3.6
- **AWS サービス:** S3、CloudFront、ACM、IAM、Route 53
- **CloudFront Functions:** Basic 認証・セキュリティヘッダー（JavaScript）

## Prerequisites

- [mise](https://mise.jdx.dev/) — ランタイムバージョン管理
- Terraform 1.14.9（`mise install` で自動インストール）
- AWS CLI（認証済み）
- S3 バックエンド用バケット `c2-terraform-state-prod`（初回は bootstrap で作成）

## Setup

1. リポジトリをクローン

   ```bash
   git clone https://github.com/co6tter/terraform-v2.git
   cd terraform-v2
   ```

2. Terraform をインストール

   ```bash
   mise install
   ```

3. 変数ファイルを作成

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars を編集して各変数を設定
   ```

   | 変数 | 説明 | 例 |
   |------|------|----|
   | `zone_name` | Route 53 ホストゾーン名（末尾ドット推奨） | `example.com.` |
   | `domain_name` | CloudFront に割り当てる FQDN | `cdn.example.com` |
   | `repo` | GitHub リポジトリ（`owner/repo`） | `co6tter/my-site` |
   | `basic_auth_username` | Basic 認証ユーザー名 | `admin` |
   | `basic_auth_password` | Basic 認証パスワード | `s3cr3t` |

4. **初回のみ** — `bootstrap/` で Terraform ステート用 S3 バケットを作成

   ```bash
   cd bootstrap
   terraform init
   terraform apply
   cd ..
   ```

5. S3 バックエンドへ移行

   ```bash
   terraform init -migrate-state
   ```

6. 差分ゼロを確認

   ```bash
   terraform plan
   ```

## Usage

```bash
# 変更のプレビュー
terraform plan

# インフラ適用
terraform apply

# 特定リソースのみ適用
terraform apply -target=aws_cloudfront_distribution.this
```

### インフラの破棄

```bash
# 状態バケットを参照外しにしてから destroy
terraform state rm aws_s3_bucket.tfstate
terraform destroy -auto-approve

# 必要であれば状態バケットを再 import
terraform import aws_s3_bucket.tfstate c2-terraform-state-prod
```

> **Note:** `terraform import` で必要な識別子はリソース種別によって異なります（ID、Name など）。

## Directory Structure

```
terraform-v2/
├── bootstrap/                    # 初回のみ実行 — ステート用 S3 バケット作成
│   ├── main.tf
│   ├── provider.tf
│   └── variables.tf
├── templates/
│   ├── basic_auth.js.tftpl       # Basic 認証 CloudFront Function
│   └── security_headers.js.tftpl # セキュリティヘッダー CloudFront Function
├── acm.tf              # ACM 証明書と Route 53 DNS 検証
├── backend.tf          # S3 バックエンド設定
├── cloudfront.tf       # CloudFront ディストリビューション・OAC・Functions
├── iam.tf              # IAM ポリシー（GitHub Actions OIDC など）
├── locals.tf           # ローカル変数
├── outputs.tf          # 出力値（CloudFront URL など）
├── provider.tf         # Terraform / AWS プロバイダー設定
├── s3.tf               # S3 バケット（コンテンツ・ログ）
├── variables.tf        # 入力変数定義
├── terraform.tfvars    # 実際の変数値（git 管理外）
└── terraform.tfvars.example  # 変数テンプレート
```

## License

MIT
