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

## 基本概念

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
├── templates/          # K8s マニフェストのテンプレート
│   ├── deployment.yaml #  {{ .Values.replicaCount }}
│   ├── service.yaml
│   └── _helpers.tpl
└── charts/             # 依存 Chart
```

## Helm v2 vs v3（試験に出る！）

| | v2 | v3 (現行) |
|--|-----|-----------|
| **Tiller** | 必要（クラスター内） | **不要** ← ここが出る |
| セキュリティ | Tiller に権限集中 | RBAC ベース |

---

## AKS ハンズオン

### 1. Helm の基本操作

```bash
# Helm のバージョンを確認（v3 であることを確認）
helm version

# インストール済みの Release を一覧表示
helm list --all-namespaces
```

### 2. Helm リポジトリの操作

```bash
# NGINX Ingress Controller の Chart リポジトリを追加
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# リポジトリのインデックスを更新（最新の Chart 情報を取得）
helm repo update

# リポジトリ内の Chart を検索
helm search repo ingress-nginx
```

### 3. Chart のインストール

```bash
# NGINX Ingress Controller をインストール
#   --create-namespace : Namespace がなければ自動作成
#   --namespace        : インストール先の Namespace
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace --namespace ingress-nginx

# Release の状態を確認
helm list -n ingress-nginx

# インストールされた K8s リソースを確認
kubectl get all -n ingress-nginx
```

### 4. テンプレートの確認（ドライラン）

```bash
# 実際にインストールせず、テンプレートの展開結果だけ表示
#   → values.yaml の値がどう展開されるか確認できる
helm template my-release ingress-nginx/ingress-nginx | head -80

# values.yaml のデフォルト値を表示
helm show values ingress-nginx/ingress-nginx | head -40
```

### 🧹 クリーンアップ

```bash
# Helm Release をアンインストール（関連する K8s リソースも削除される）
helm uninstall ingress-nginx -n ingress-nginx

# Namespace を削除（残っている場合）
kubectl delete namespace ingress-nginx --ignore-not-found

# Helm リポジトリを削除（任意）
helm repo remove ingress-nginx

# 確認
helm list --all-namespaces
# ingress-nginx が表示されなければ OK
```

---

## KCNA 試験チェックリスト

- [ ] Helm = K8s のパッケージマネージャ
- [ ] Chart / Release / Repository の関係
- [ ] values.yaml でカスタマイズ
- [ ] **Helm v3 で Tiller が不要になった** ← 頻出
- [ ] `helm install / upgrade / rollback` の流れ
