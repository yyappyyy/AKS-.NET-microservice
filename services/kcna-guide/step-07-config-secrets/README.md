# Step 07: ConfigMap と Secret

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- ConfigMap と Secret の違いを理解する
- 環境変数やファイルとして設定を注入する方法を学ぶ
- 12 Factor App の Config 原則との関連を理解する

---

## なぜ設定を外部化するか（12 Factor App #3）

```
❌ コードにハードコード                ✅ ConfigMap で外部化
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
  namespace: product-catalog
data:
  ASPNETCORE_ENVIRONMENT: "Production"   # ← .NET の環境設定
  ASPNETCORE_URLS: "http://+:8080"       # ← リッスンポート
```

`deployment.yaml` での注入:

```yaml
spec:
  containers:
    - name: product-catalog
      envFrom:
        - configMapRef:
            name: product-catalog-config   # ← 全キーを環境変数に
```

## Secret

**機密情報**（パスワード、API キー、証明書）を管理:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: YWRtaW4=           # ← echo -n "admin" | base64
  password: cGFzc3dvcmQxMjM=   # ← echo -n "password123" | base64
```

> **⚠️ 重要: Secret は base64 エンコードであり、暗号化ではない！**
> AKS では Azure Key Vault + CSI Driver で本格的な秘密管理を行う。

---

## 注入方法の比較

| 方法 | 用途 |
|------|------|
| `envFrom` | 全キーを環境変数に（簡単） |
| `env[].valueFrom` | 個別キーを環境変数に（名前変更可能） |
| Volume マウント | ファイルとして配置（nginx.conf 等） |

---

## AKS ハンズオン

### 1. 既存の ConfigMap を確認（Product Catalog）

```bash
# product-catalog Namespace の ConfigMap 一覧
kubectl get configmap -n product-catalog

# ConfigMap の中身を表示（data セクションにキーと値が見える）
kubectl describe configmap product-catalog-config -n product-catalog

# YAML 形式で出力（マニフェストの構造を確認）
kubectl get configmap product-catalog-config -n product-catalog -o yaml
```

### 2. ConfigMap をコマンドで作成

```bash
# --from-literal でキーと値を指定して作成
kubectl create configmap test-config \
  --from-literal=KEY1=value1 \
  --from-literal=KEY2=value2

# 作成されたことを確認
kubectl get configmap test-config -o yaml
```

### 3. Secret をコマンドで作成

```bash
# generic タイプの Secret を作成（値は自動で base64 エンコードされる）
kubectl create secret generic test-secret \
  --from-literal=username=admin \
  --from-literal=password=mysecret

# Secret の概要を確認（data の中身は表示されない）
kubectl describe secret test-secret

# Secret の値を base64 デコードして確認
kubectl get secret test-secret -o jsonpath='{.data.password}' | base64 -d
# 出力: mysecret

kubectl get secret test-secret -o jsonpath='{.data.username}' | base64 -d
# 出力: admin
```

### 🧹 クリーンアップ

```bash
# 学習用の ConfigMap と Secret を削除
kubectl delete configmap test-config
kubectl delete secret test-secret

# 削除確認
kubectl get configmap,secret | grep test
# 何も表示されなければ OK
```

---

## KCNA 試験チェックリスト

- [ ] ConfigMap = 非機密設定、Secret = 機密情報
- [ ] Secret は **base64 エンコード**であり暗号化ではない
- [ ] envFrom / env / Volume の 3 つの注入方法
- [ ] 12 Factor App の Config 原則との関連
