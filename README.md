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
- GitHub Actions (CI/CD)
- Azure Container Registry (ACR)

## プロジェクト構成

```
├── services/                               # マイクロサービス群
│   ├── product-catalog/                    # 商品カタログサービス ✅
│   │   ├── src/ProductCatalog.Api/         #   API ソースコード
│   │   ├── tests/ProductCatalog.Api.Tests/ #   テスト
│   │   ├── Dockerfile                      #   Docker ビルド定義
│   │   └── ProductCatalog.slnx             #   ソリューションファイル
│   ├── order-management/                   # 注文管理サービス（予定）
│   └── user-service/                       # ユーザーサービス（予定）
│
├── k8s/                                    # Kubernetes マニフェスト
│   ├── base/                               #   共通リソース（namespace 等）
│   └── product-catalog/                    #   サービス別マニフェスト
│
├── .github/workflows/                      # CI/CD パイプライン
│   └── product-catalog.yaml                #   サービス別ワークフロー
│
├── .gitignore
├── .dockerignore
├── LICENSE
└── README.md
```

> **新しいサービスの追加方法:** `services/<name>/` + `k8s/<name>/` + `.github/workflows/<name>.yaml` を追加するだけで、独立してビルド・テスト・デプロイが可能です。

---

## 前提条件（Prerequisites）

以下のツールをインストールしてください。

| ツール | 用途 | インストール |
|--------|------|-------------|
| .NET 10 SDK | ビルド・実行 | [公式サイト](https://dotnet.microsoft.com/download/dotnet/10.0) |
| Docker Desktop | コンテナビルド | [公式サイト](https://www.docker.com/products/docker-desktop/) |
| Azure CLI (`az`) | Azure リソース管理 | [公式ドキュメント](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli) |
| kubectl | Kubernetes 操作 | [公式ドキュメント](https://kubernetes.io/ja/docs/tasks/tools/) |
| GitHub CLI (`gh`) | （任意）PR・Issue 操作 | [公式サイト](https://cli.github.com/) |

---

## ローカル開発

### dotnet run で起動

```bash
cd services/product-catalog/src/ProductCatalog.Api
dotnet run
```

起動後、以下にアクセスできます:
- API: http://localhost:5000/api/products
- OpenAPI (Swagger): http://localhost:5000/openapi/v1.json
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
| `GET` | `/api/products` | 全商品を取得（`?category=` でフィルタ可能） |
| `GET` | `/api/products/{id}` | 指定 ID の商品を取得 |
| `POST` | `/api/products` | 新しい商品を作成 |
| `PUT` | `/api/products/{id}` | 指定 ID の商品を更新 |
| `DELETE` | `/api/products/{id}` | 指定 ID の商品を削除 |
| `GET` | `/healthz` | Liveness ヘルスチェック |
| `GET` | `/readyz` | Readiness ヘルスチェック |

### curl サンプル

```bash
# 全商品取得
curl http://localhost:8080/api/products

# カテゴリでフィルタ
curl "http://localhost:8080/api/products?category=食品"

# 商品作成
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "サンプル商品",
    "description": "商品の説明",
    "price": 1500,
    "category": "食品"
  }'

# 商品取得（ID 指定）
curl http://localhost:8080/api/products/{id}

# 商品更新
curl -X PUT http://localhost:8080/api/products/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "name": "更新後の商品名",
    "description": "更新後の説明",
    "price": 2000,
    "category": "食品"
  }'

# 商品削除
curl -X DELETE http://localhost:8080/api/products/{id}
```

---

## Azure 環境セットアップ（ステップバイステップ）

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

## AKS への手動デプロイ

CI/CD を使わずに手動でデプロイする場合の手順です。

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
# Pod の状態確認
kubectl get pods -n product-catalog
# 出力例:
# NAME                              READY   STATUS    RESTARTS   AGE
# product-catalog-6b8f9c4d5-abc12   1/1     Running   0          30s
# product-catalog-6b8f9c4d5-def34   1/1     Running   0          30s

# Service の確認
kubectl get svc -n product-catalog

# ログの確認
kubectl logs -n product-catalog -l app=product-catalog --tail=50

# Pod の詳細確認（トラブルシューティング時）
kubectl describe pods -n product-catalog -l app=product-catalog
```

### 4. サービスへのアクセス

```bash
# ポートフォワードでローカルからアクセス
kubectl port-forward -n product-catalog svc/product-catalog 8080:80

# 別ターミナルで API を確認
curl http://localhost:8080/api/products
curl http://localhost:8080/healthz
```

---

## GitHub Actions CI/CD セットアップ

### 1. Azure サービスプリンシパルの作成

GitHub Actions から Azure にアクセスするためのサービスプリンシパルを作成します。

```bash
# サブスクリプション ID を取得
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# サービスプリンシパル作成
az ad sp create-for-rbac \
  --name "github-actions-aks-microservices" \
  --role contributor \
  --scopes /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP} \
  --sdk-auth
```

上記コマンドの出力（JSON）を控えてください。次のステップで使用します。

出力例:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  ...
}
```

### 2. ACR の認証情報を取得

```bash
# ACR のユーザー名とパスワードを取得
az acr credential show --name $ACR_NAME --output table
# 出力例:
# USERNAME      PASSWORD                          PASSWORD2
# yourAcrName   xxxxxxxxxxxxxxxxxxxxxxxxxxxx      xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 3. GitHub Secrets の設定

リポジトリの **Settings** → **Secrets and variables** → **Actions** → **New repository secret** から以下を登録します。

| Secret 名 | 説明 | 取得方法 |
|------------|------|----------|
| `AZURE_CREDENTIALS` | サービスプリンシパルの JSON 全文 | 手順1 の `az ad sp create-for-rbac` の出力をそのまま貼り付け |
| `ACR_LOGIN_SERVER` | ACR のログインサーバー名 | `az acr show --name $ACR_NAME --query loginServer -o tsv` |
| `ACR_USERNAME` | ACR のユーザー名 | `az acr credential show --name $ACR_NAME --query username -o tsv` |
| `ACR_PASSWORD` | ACR のパスワード | `az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv` |
| `AKS_RESOURCE_GROUP` | AKS のリソースグループ名 | 手順2 で設定した `$RESOURCE_GROUP` の値（例: `rg-aks-microservices`） |
| `AKS_CLUSTER_NAME` | AKS クラスター名 | 手順4 で設定した `$AKS_CLUSTER` の値（例: `aks-microservices`） |

### 4. パイプラインの動作フロー

```
main ブランチへの Push / PR
        │
        ▼
┌─────────────────────┐
│  Build & Test       │  ← すべての Push / PR で実行
│  - dotnet restore   │
│  - dotnet build     │
│  - dotnet test      │
└──────────┬──────────┘
           │ (main ブランチへの Push のみ)
           ▼
┌─────────────────────┐
│  Docker Build & Push│  ← ACR にイメージを Push
│  - docker build     │     タグ: commit SHA + latest
│  - docker push      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Deploy to AKS      │  ← K8s マニフェスト適用 & イメージ更新
│  - kubectl apply    │
│  - kubectl set image│
│  - rollout status   │
└─────────────────────┘
```

> **paths フィルタ:** `services/product-catalog/**` 配下のファイル変更時のみワークフローが実行されます。他のサービスの変更では実行されません。

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
A: 手動デプロイの場合は `sed` コマンドで置換します（[手動デプロイ手順](#2-k8s-マニフェストを適用)参照）。CI/CD の場合は `kubectl set image` で自動的にイメージが更新されます。

**Q: 新しいマイクロサービスを追加するには？**
A: 以下の3つを追加してください:
1. `services/<サービス名>/` — .NET プロジェクト + Dockerfile
2. `k8s/<サービス名>/` — Kubernetes マニフェスト一式
3. `.github/workflows/<サービス名>.yaml` — CI/CD ワークフロー

**Q: DB を追加するには？**
A: 現在はインメモリストア（`ConcurrentDictionary`）を使用しています。DB を追加する場合は `IProductService` の新しい実装を作成し、DI 登録を差し替えてください。

---

## ライセンス

[MIT License](LICENSE)