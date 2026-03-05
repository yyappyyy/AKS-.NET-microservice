# Step 11: Helm

> **KCNA 配点: Cloud Native Application Delivery — 8%**

## 学習目標

- Helm の役割と基本概念を理解する
- Chart / Release / Repository の関係を理解する
- Helm v3 で Tiller が不要になったことを知る

---

## Helm = Kubernetes のパッケージマネージャ

```
apt (Ubuntu)     ⟷  Helm (Kubernetes)
.deb パッケージ   ⟷  Chart
apt repository   ⟷  Helm Repository
インストール済み   ⟷  Release
```

| 概念 | 説明 |
|------|------|
| **Chart** | K8s マニフェストのテンプレート集 |
| **Release** | Chart をインストールしたインスタンス |
| **Repository** | Chart の保管場所 |
| **values.yaml** | カスタマイズパラメータ |

## Chart の構造

```
my-chart/
├── Chart.yaml          # メタデータ（名前、バージョン）
├── values.yaml         # デフォルト設定値
├── templates/          # テンプレート（{{ .Values.xxx }}）
│   ├── deployment.yaml
│   ├── service.yaml
│   └── _helpers.tpl
└── charts/             # 依存 Chart
```

## Helm v2 vs v3（試験に出る！）

| | v2 | v3 (現行) |
|--|-----|-----------|
| **Tiller** | 必要 | **不要** ← 頻出 |
| セキュリティ | Tiller に権限集中 | RBAC ベース |
| Release | クラスター全体 | Namespace スコープ |

---

## AKS ハンズオン

### 1. Helm の基本

```bash
# バージョン確認（v3 であること）
helm version

# インストール済み Release 一覧
helm list --all-namespaces

# Helm 環境情報
helm env
```

### 2. リポジトリ操作

```bash
# リポジトリを追加
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add bitnami https://charts.bitnami.com/bitnami

# リポジトリ一覧
helm repo list

# インデックスを更新
helm repo update

# Chart を検索
helm search repo nginx
helm search repo nginx --versions | head -10

# Artifact Hub（公開リポジトリ）を検索
helm search hub wordpress | head -10
```

### 3. Chart を調べる

```bash
# Chart の情報を表示
helm show chart ingress-nginx/ingress-nginx

# values.yaml のデフォルト値を表示
helm show values ingress-nginx/ingress-nginx | head -50

# 全情報を表示
helm show all ingress-nginx/ingress-nginx | head -30
```

### 4. インストール

```bash
# NGINX Ingress Controller をインストール
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace --namespace ingress-nginx

# Release の状態
helm list -n ingress-nginx

# Release の詳細
helm status ingress-nginx -n ingress-nginx

# インストールされた K8s リソース
kubectl get all -n ingress-nginx
```

### 5. テンプレートの確認（ドライラン）

```bash
# インストールせずテンプレートの展開結果だけ表示
helm template my-release ingress-nginx/ingress-nginx | head -80

# --dry-run でインストールをシミュレート（サーバーサイド検証あり）
helm install test ingress-nginx/ingress-nginx --dry-run --namespace test-ns

# values をカスタマイズしてテンプレート確認
helm template my-release ingress-nginx/ingress-nginx --set controller.replicaCount=3 | grep replicas
```

### 6. アップグレードとロールバック

```bash
# values を変更してアップグレード
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --set controller.replicaCount=2

# リリース履歴
helm history ingress-nginx -n ingress-nginx

# ロールバック
helm rollback ingress-nginx 1 -n ingress-nginx
```

### 7. Chart の作成（学習用）

```bash
# 自分の Chart を作成（雛形が自動生成される）
helm create my-sample-chart

# 構造を確認
ls my-sample-chart/
# Chart.yaml  charts/  templates/  values.yaml

# 削除
rm -rf my-sample-chart  # Linux/Mac
# Remove-Item -Recurse my-sample-chart  # Windows
```

### 🧹 クリーンアップ

```bash
# Release をアンインストール
helm uninstall ingress-nginx -n ingress-nginx

# Namespace を削除
kubectl delete namespace ingress-nginx --ignore-not-found

# リポジトリを削除（任意）
helm repo remove ingress-nginx
helm repo remove bitnami

# 確認
helm list --all-namespaces
```

---

## KCNA 試験チェックリスト

- [ ] Helm = K8s のパッケージマネージャ
- [ ] Chart / Release / Repository の関係
- [ ] values.yaml でカスタマイズ
- [ ] **Helm v3 で Tiller が不要になった** ← 頻出
- [ ] `helm install / upgrade / rollback` の流れ
- [ ] `helm template` でドライラン（実際にインストールしない）
