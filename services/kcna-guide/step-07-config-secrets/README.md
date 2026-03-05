# Step 07: ConfigMap と Secret

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- ConfigMap と Secret の違いを理解する
- 環境変数やファイルとして設定を注入する方法を学ぶ
- 12 Factor App の Config 原則との関連を理解する

---

## なぜ設定を外部化するか（12 Factor App #3）

```
❌ ハードコード                       ✅ ConfigMap で外部化
┌──────────────┐                     ┌──────────────┐   ┌──────────┐
│ App          │                     │ App          │ ← │ConfigMap │
│ DB_HOST=mydb │   →                 │ ${DB_HOST}   │   │ DB_HOST= │
│              │                     │              │   │ mydb     │
└──────────────┘                     └──────────────┘   └──────────┘
 環境ごとにコード変更が必要             同じイメージを全環境で利用
```

## 実プロジェクトの ConfigMap

`k8s/product-catalog/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: product-catalog-config
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  ASPNETCORE_URLS: "http://+:8080"
```

`deployment.yaml` での注入:

```yaml
envFrom:
  - configMapRef:
      name: product-catalog-config   # ← 全キーを環境変数に
```

## Secret

**機密情報**を管理。`kubectl create` 時に自動で base64 エンコードされる:

> **⚠️ Secret は base64 エンコードであり、暗号化ではない！**
> AKS では Azure Key Vault + CSI Driver を使う。

### 注入方法の比較

| 方法 | 用途 |
|------|------|
| `envFrom` | 全キーを環境変数に |
| `env[].valueFrom` | 個別キーを環境変数に（名前変更可能） |
| Volume マウント | ファイルとして配置（nginx.conf 等） |

---

## AKS ハンズオン

### 1. 既存 ConfigMap を確認

```bash
# product-catalog の ConfigMap 一覧
kubectl get configmap -n product-catalog

# 中身を確認
kubectl describe configmap product-catalog-config -n product-catalog

# YAML で出力
kubectl get configmap product-catalog-config -n product-catalog -o yaml

# ConfigMap の特定キーの値だけ取得
kubectl get configmap product-catalog-config -n product-catalog \
  -o jsonpath='{.data.ASPNETCORE_ENVIRONMENT}'
```

### 2. ConfigMap をコマンドで作成

```bash
# --from-literal でキーと値を指定
kubectl create configmap test-config \
  --from-literal=KEY1=value1 \
  --from-literal=KEY2=value2

# 確認
kubectl get configmap test-config -o yaml

# ファイルから ConfigMap を作成
echo "server { listen 80; }" > /tmp/nginx.conf
kubectl create configmap nginx-config --from-file=/tmp/nginx.conf

# 確認
kubectl describe configmap nginx-config

# YAML を生成（ファイルに保存して使い回す用）
kubectl create configmap sample-config \
  --from-literal=DB_HOST=mydb --dry-run=client -o yaml
```

### 3. Secret をコマンドで作成

```bash
# generic Secret を作成（値は自動 base64 エンコード）
kubectl create secret generic test-secret \
  --from-literal=username=admin \
  --from-literal=password=mysecret123

# Secret の概要（data の値は非表示）
kubectl describe secret test-secret

# Secret の全情報（base64 エンコード済み値が見える）
kubectl get secret test-secret -o yaml

# base64 デコードして中身を確認
kubectl get secret test-secret -o jsonpath='{.data.password}' | base64 -d
# 出力: mysecret123

kubectl get secret test-secret -o jsonpath='{.data.username}' | base64 -d
# 出力: admin
```

### 4. Pod に ConfigMap / Secret を注入して確認

```bash
# ConfigMap を使った Pod を Imperative に作成
kubectl run cm-demo --image=busybox \
  --env="STATIC_VAR=hello" \
  --command -- sh -c "env | sort && sleep 3600"

# Pod 内の環境変数を確認
kubectl exec cm-demo -- env | grep -E "STATIC|KEY"

# 削除
kubectl delete pod cm-demo
```

### 5. Secret のタイプを確認

```bash
# クラスター内の全 Secret を表示（タイプ列に注目）
kubectl get secrets -A | head -20
# Opaque                   : 汎用 Secret
# kubernetes.io/tls        : TLS 証明書
# kubernetes.io/dockerconfigjson : Docker レジストリ認証

# TLS Secret の作成例（自己署名証明書がある場合）
# kubectl create secret tls my-tls --cert=tls.crt --key=tls.key

# Docker レジストリ Secret の作成例
# kubectl create secret docker-registry my-registry \
#   --docker-server=myregistry.azurecr.io \
#   --docker-username=user --docker-password=pass
```

### 🧹 クリーンアップ

```bash
# 学習用リソースを削除
kubectl delete configmap test-config nginx-config --ignore-not-found
kubectl delete secret test-secret --ignore-not-found
kubectl delete pod cm-demo --ignore-not-found

# 確認
kubectl get configmap,secret | grep -E "test|nginx"
```

---

## KCNA 試験チェックリスト

- [ ] ConfigMap = 非機密設定、Secret = 機密情報
- [ ] Secret は **base64 エンコード**であり暗号化ではない
- [ ] envFrom / env / Volume の 3 つの注入方法
- [ ] 12 Factor App の Config 原則との関連
- [ ] Secret のタイプ: Opaque, kubernetes.io/tls, dockerconfigjson
