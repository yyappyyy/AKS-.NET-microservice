# AKS .NET Microservices

Azure Kubernetes Service (AKS) 上で動作する .NET マイクロサービス群のモノレポです。

## アーキテクチャ

```
┌──────────────┐    ┌─────────────────────────────────────────┐
│   Client     │    │           Azure Kubernetes Service       │
│              │───▶│  ┌─────────┐    ┌────────────────────┐  │
│              │    │  │ Ingress │───▶│  Product Catalog   │  │
│              │    │  │ (nginx) │    │  (.NET 10 API)     │  │
│              │    │  │         │    │  ┌──────────────┐   │  │
│              │    │  │         │    │  │  Pod (×2~10) │   │  │
│              │    │  │         │    │  └──────────────┘   │  │
│              │    │  │         │    └────────────────────┘  │
│              │    │  │         │    ┌────────────────────┐  │
│              │    │  │         │───▶│  (将来のサービス)   │  │
│              │    │  └─────────┘    └────────────────────┘  │
└──────────────┘    └─────────────────────────────────────────┘
                    ┌─────────────────────┐
                    │  Azure Container    │
                    │  Registry (ACR)     │
                    │  Docker イメージ保管  │
                    └─────────────────────┘
```

**技術スタック:**
- .NET 10 (Minimal API)
- Docker (マルチステージビルド)
- Kubernetes (AKS)
- Azure Container Registry (ACR)
- GitHub Actions (CI/CD) ※オプション

## プロジェクト構成

```
├── services/                               # マイクロサービス群 & 学習ガイド
│   ├── product-catalog/                    # 商品カタログサービス ✅
│   │   ├── src/ProductCatalog.Api/         #   API ソースコード
│   │   ├── tests/ProductCatalog.Api.Tests/ #   テスト
│   │   ├── Dockerfile                      #   Docker ビルド定義
│   │   └── ProductCatalog.slnx             #   ソリューションファイル
│   ├── kcna-guide/                         # KCNA 学習ガイド (15 Steps) ✅
│   ├── cka-guide/                          # CKA 学習ガイド (15 Steps) ✅
│   ├── ckad-guide/                         # CKAD 学習ガイド (15 Steps) ✅
│   ├── order-management/                   # 注文管理サービス（予定）
│   └── user-service/                       # ユーザーサービス（予定）
│
├── scripts/                                # セットアップ・デプロイスクリプト
│   ├── azure-env.sample                    #   環境変数テンプレート
│   ├── setup-azure.sh / .ps1               #   Azure 環境セットアップ
│   └── deploy.sh / .ps1                    #   AKS デプロイ
│
├── k8s/                                    # Kubernetes マニフェスト
│   ├── base/                               #   共通リソース（namespace 等）
│   └── product-catalog/                    #   サービス別マニフェスト
│
├── .github/workflows/                      # CI/CD パイプライン（オプション）
│   └── product-catalog.yaml                #   サービス別ワークフロー
│
├── .gitignore
├── .dockerignore
├── LICENSE
└── README.md
```

> **新しいサービスの追加方法:** `services/<name>/` + `k8s/<name>/` を追加するだけで、独立してビルド・テスト・デプロイが可能です。

---

## Kubernetes 認定資格 学習ガイド

本リポジトリには、Kubernetes 認定資格の学習ガイドを 3 つ収録しています。
すべて **AKS 環境でそのまま実行可能** なハンズオン形式です。

| ガイド | 対象資格 | ステップ数 | 特徴 |
|--------|----------|-----------|------|
| [KCNA Guide](services/kcna-guide/README.md) | Kubernetes and Cloud Native Associate | 15 Steps (20 files) | 概念理解 + クイズ中心。クラウドネイティブの基礎から試験対策まで |
| [CKA Guide](services/cka-guide/README.md) | Certified Kubernetes Administrator | 15 Steps (16 files) | クラスタ管理・障害対応のコマンド演習。etcd バックアップ、ノードトラブルシュートなど |
| [CKAD Guide](services/ckad-guide/README.md) | Certified Kubernetes Application Developer | 15 Steps (16 files) | アプリ開発者向け。Pod 設計、マルチコンテナ、Helm/Kustomize、模擬試験 15 問 |

### 学習の進め方

```
KCNA (基礎) → CKA (管理者) → CKAD (開発者)
```

1. **KCNA** — Kubernetes の概念を理解（初学者はここから）
2. **CKA** — クラスタの構築・管理・保守を学ぶ
3. **CKAD** — アプリケーションの設計・デプロイ・運用を学ぶ

> 各ステップは独立した Namespace を使用し、最後に `kubectl delete namespace` でクリーンアップできます。

---

## 前提条件（Prerequisites）

以下のツールをインストールしてください。

| ツール | 用途 | インストール |
|--------|------|-------------|
| .NET 10 SDK | ビルド・実行 | [公式サイト](https://dotnet.microsoft.com/download/dotnet/10.0) |
| Docker Desktop | コンテナビルド | [公式サイト](https://www.docker.com/products/docker-desktop/) |
| Azure CLI (`az`) | Azure リソース管理 | [公式ドキュメント](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli) |
| kubectl | Kubernetes 操作 | [公式ドキュメント](https://kubernetes.io/ja/docs/tasks/tools/) |

---

## ローカル開発

### dotnet run で起動

```bash
cd services/product-catalog/src/ProductCatalog.Api
dotnet run
```

起動後、以下にアクセスできます:
- **UI (管理画面)**: http://localhost:5000/
- API: http://localhost:5000/api/products
- OpenAPI Spec: http://localhost:5000/openapi/v1.json
- ヘルスチェック: http://localhost:5000/healthz

### Docker で起動

```bash
# ビルド
cd services/product-catalog
docker build -t product-catalog:local .

# 起動
docker run -p 8080:8080 product-catalog:local
```

起動後、以下にアクセスできます:
- **UI (管理画面)**: http://localhost:8080/
- API: http://localhost:8080/api/products
- ヘルスチェック: http://localhost:8080/healthz

### テスト実行

```bash
cd services/product-catalog
dotnet test
```

---

## API エンドポイント一覧

### 商品カタログサービス (`/api/products`)

| メソッド | パス | 説明 |
|---------|------|------|
| `GET` | `/` | UI 管理画面 |
| `GET` | `/api/products` | 全商品を取得（`?category=` でフィルタ可能） |
| `GET` | `/api/products/{id}` | 指定 ID の商品を取得 |
| `POST` | `/api/products` | 新しい商品を作成 |
| `PUT` | `/api/products/{id}` | 指定 ID の商品を更新 |
| `DELETE` | `/api/products/{id}` | 指定 ID の商品を削除 |
| `GET` | `/healthz` | Liveness ヘルスチェック |
| `GET` | `/readyz` | Readiness ヘルスチェック |
| `GET` | `/openapi/v1.json` | OpenAPI 仕様 (開発環境のみ) |

### curl サンプル

```bash
# 全商品取得
curl http://localhost:5000/api/products

# カテゴリでフィルタ
curl "http://localhost:5000/api/products?category=食品"

# 商品作成
curl -X POST http://localhost:5000/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "サンプル商品",
    "description": "商品の説明",
    "price": 1500,
    "category": "食品"
  }'

# 商品取得（ID 指定）
curl http://localhost:5000/api/products/{id}

# 商品更新
curl -X PUT http://localhost:5000/api/products/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "name": "更新後の商品名",
    "description": "更新後の説明",
    "price": 2000,
    "category": "食品"
  }'

# 商品削除
curl -X DELETE http://localhost:5000/api/products/{id}
```

> **Note:** Docker 起動時は `localhost:5000` を `localhost:8080` に読み替えてください。

---

## Azure 環境セットアップ（ステップバイステップ）

> **💡 スクリプトで一括セットアップ（推奨）**
>
> 以下の手順をまとめたスクリプトを用意しています。
>
> ```bash
> # 1. 環境変数ファイルを作成して編集
> cp scripts/azure-env.sample scripts/azure-env.sh   # Bash の場合
> cp scripts/azure-env.sample scripts/azure-env.ps1   # PowerShell の場合
> # ※ ファイルを開いて SUBSCRIPTION_ID, ACR_NAME 等を自分の値に変更
>
> # 2. セットアップ実行
> ./scripts/setup-azure.sh        # Bash
> .\scripts\setup-azure.ps1       # PowerShell
>
> # 3. デプロイ
> ./scripts/deploy.sh             # Bash
> .\scripts\deploy.ps1            # PowerShell
> ```
>
> `azure-env.sh` / `azure-env.ps1` は `.gitignore` に含まれているため、
> 個人の設定値が Git にコミットされる心配はありません。

以下は各ステップの詳細です。

### 1. Azure CLI ログイン

```bash
# Azure にログイン（ブラウザが開きます）
az login

# 使用するサブスクリプションを設定
az account set --subscription "<サブスクリプションID>"

# 確認
az account show --output table
```

### 2. リソースグループ作成

```bash
# 変数を設定（以降のコマンドで使用）
RESOURCE_GROUP="rg-aks-microservices"
LOCATION="japaneast"

# リソースグループ作成
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 3. Azure Container Registry (ACR) 作成

```bash
ACR_NAME="yourAcrName"  # グローバルで一意な名前を指定

# ACR 作成
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --location $LOCATION

# ACR にログイン
az acr login --name $ACR_NAME

# ログインサーバー名を確認（後で使用）
az acr show --name $ACR_NAME --query loginServer --output tsv
# 出力例: yourAcrName.azurecr.io
```

### 4. AKS クラスター作成

```bash
AKS_CLUSTER="aks-microservices"

# AKS クラスター作成（ACR との連携を含む）
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --generate-ssh-keys \
  --attach-acr $ACR_NAME \
  --location $LOCATION

# ※ クラスター作成には数分かかります
```

### 5. AKS クレデンシャル取得（kubectl 接続）

```bash
# kubectl の接続設定を取得
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER

# 接続確認
kubectl get nodes
# 出力例:
# NAME                                STATUS   ROLES    AGE   VERSION
# aks-nodepool1-12345678-vmss000000   Ready    <none>   5m    v1.29.x
# aks-nodepool1-12345678-vmss000001   Ready    <none>   5m    v1.29.x

# クラスター情報の確認
kubectl cluster-info
```

---

## AKS へのデプロイ

### 1. Docker イメージをビルドして ACR に Push

```bash
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

# Docker イメージをビルド
cd services/product-catalog
docker build -t ${ACR_LOGIN_SERVER}/product-catalog:latest .

# ACR にログイン
az acr login --name $ACR_NAME

# ACR に Push
docker push ${ACR_LOGIN_SERVER}/product-catalog:latest
```

### 2. K8s マニフェストを適用

```bash
# deployment.yaml のイメージ名を実際の ACR ログインサーバー名に置換
sed -i "s|<ACR_LOGIN_SERVER>|${ACR_LOGIN_SERVER}|g" k8s/product-catalog/deployment.yaml

# マニフェスト適用
kubectl apply -f k8s/base/
kubectl apply -f k8s/product-catalog/
```

### 3. デプロイ確認

```bash
# Pod の状態確認（STATUS が Running になるまで待つ）
kubectl get pods -n product-catalog -w
# 出力例:
# NAME                              READY   STATUS    RESTARTS   AGE
# product-catalog-6b8f9c4d5-abc12   1/1     Running   0          30s
# product-catalog-6b8f9c4d5-def34   1/1     Running   0          30s

# Service の確認
kubectl get svc -n product-catalog

# Deployment のロールアウト状態を確認
kubectl rollout status deployment/product-catalog -n product-catalog

# ログの確認
kubectl logs -n product-catalog -l app=product-catalog --tail=50
```

### 4. 動作確認（ポートフォワード）

```bash
# ポートフォワードでローカルからアクセス
kubectl port-forward -n product-catalog svc/product-catalog 8080:80
```

別ターミナルで API を確認:

```bash
# ヘルスチェック
curl http://localhost:8080/healthz
# 期待値: Healthy

curl http://localhost:8080/readyz
# 期待値: Healthy

# 商品一覧（初期状態は空）
curl http://localhost:8080/api/products
# 期待値: []

# 商品を作成
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"テスト商品","description":"AKS上で動作確認","price":1000,"category":"テスト"}'

# 作成した商品を確認
curl http://localhost:8080/api/products
```

### 5. イメージ更新時の再デプロイ

コード変更後にイメージを更新してデプロイする手順:

```bash
# 新しいイメージをビルド & Push
cd services/product-catalog
docker build -t ${ACR_LOGIN_SERVER}/product-catalog:v2 .
docker push ${ACR_LOGIN_SERVER}/product-catalog:v2

# Deployment のイメージを更新
kubectl set image deployment/product-catalog \
  product-catalog=${ACR_LOGIN_SERVER}/product-catalog:v2 \
  -n product-catalog

# ロールアウト状態を確認
kubectl rollout status deployment/product-catalog -n product-catalog

# 問題があればロールバック
# kubectl rollout undo deployment/product-catalog -n product-catalog
```

### 6. リソースの確認コマンド一覧

```bash
# 全リソースの状態を一覧表示
kubectl get all -n product-catalog

# HPA（オートスケーラー）の状態確認
kubectl get hpa -n product-catalog

# Ingress の状態確認
kubectl get ingress -n product-catalog

# Pod の詳細（トラブルシューティング時）
kubectl describe pods -n product-catalog -l app=product-catalog

# リソース使用量（metrics-server が必要）
kubectl top pods -n product-catalog
```

---

## トラブルシューティング

### Pod が起動しない / CrashLoopBackOff になる

```bash
# Pod の状態を確認
kubectl get pods -n product-catalog

# Pod のイベントを確認
kubectl describe pod <pod-name> -n product-catalog

# アプリケーションログを確認
kubectl logs <pod-name> -n product-catalog

# 直前のクラッシュのログを確認
kubectl logs <pod-name> -n product-catalog --previous
```

### ACR からのイメージ Pull に失敗する（ImagePullBackOff）

```bash
# AKS と ACR の連携状態を確認
az aks check-acr \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --acr ${ACR_NAME}.azurecr.io

# 連携が切れている場合は再アタッチ
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --attach-acr $ACR_NAME
```

### ヘルスチェックが失敗する

```bash
# Pod 内からヘルスチェックを直接確認
kubectl exec -it <pod-name> -n product-catalog -- curl -s http://localhost:8080/healthz

# Deployment のプローブ設定を確認
kubectl get deployment product-catalog -n product-catalog -o yaml | grep -A 10 "livenessProbe\|readinessProbe"
```

### サービスに外部からアクセスできない

```bash
# Service と Endpoints を確認
kubectl get svc -n product-catalog
kubectl get endpoints -n product-catalog

# Ingress の状態を確認
kubectl get ingress -n product-catalog
kubectl describe ingress product-catalog -n product-catalog

# ポートフォワードで直接アクセスを試す
kubectl port-forward -n product-catalog svc/product-catalog 8080:80
curl http://localhost:8080/healthz
```

### よくある質問

**Q: deployment.yaml の `<ACR_LOGIN_SERVER>` はどう設定する？**
A: `sed` コマンドで置換します（[デプロイ手順 ステップ2](#2-k8s-マニフェストを適用) 参照）。

**Q: 新しいマイクロサービスを追加するには？**
A: 以下の2つを追加してください:
1. `services/<サービス名>/` — .NET プロジェクト + Dockerfile
2. `k8s/<サービス名>/` — Kubernetes マニフェスト一式

**Q: DB を追加するには？**
A: 現在はインメモリストア（`ConcurrentDictionary`）を使用しています。DB を追加する場合は `IProductService` の新しい実装を作成し、DI 登録を差し替えてください。

---

## 付録: GitHub Actions CI/CD セットアップ（オプション）

手動デプロイではなく CI/CD で自動化したい場合は、以下の手順で GitHub Actions を設定できます。
ワークフローファイルは `.github/workflows/product-catalog.yaml` に用意済みです。

### 1. Azure サービスプリンシパルの作成

```bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

az ad sp create-for-rbac \
  --name "github-actions-aks-microservices" \
  --role contributor \
  --scopes /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP} \
  --sdk-auth
```

上記コマンドの出力（JSON）を控えてください。

### 2. ACR の認証情報を取得

```bash
az acr credential show --name $ACR_NAME --output table
```

### 3. GitHub Secrets の設定

リポジトリの **Settings** → **Secrets and variables** → **Actions** → **New repository secret** から以下を登録します。

| Secret 名 | 説明 | 取得方法 |
|------------|------|----------|
| `AZURE_CREDENTIALS` | サービスプリンシパルの JSON 全文 | `az ad sp create-for-rbac --sdk-auth` の出力 |
| `ACR_LOGIN_SERVER` | ACR のログインサーバー名 | `az acr show --name $ACR_NAME --query loginServer -o tsv` |
| `ACR_USERNAME` | ACR のユーザー名 | `az acr credential show --name $ACR_NAME --query username -o tsv` |
| `ACR_PASSWORD` | ACR のパスワード | `az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv` |
| `AKS_RESOURCE_GROUP` | AKS のリソースグループ名 | 例: `rg-aks-microservices` |
| `AKS_CLUSTER_NAME` | AKS クラスター名 | 例: `aks-microservices` |

### 4. パイプラインの動作フロー

```
main ブランチへの Push / PR (services/product-catalog/** 変更時のみ)
        │
        ▼
┌─────────────────────┐
│  Build & Test       │
└──────────┬──────────┘
           │ (main Push のみ)
           ▼
┌─────────────────────┐
│  Docker Build & Push│  → ACR
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  Deploy to AKS      │
└─────────────────────┘
```

---

## ライセンス

[MIT License](LICENSE)