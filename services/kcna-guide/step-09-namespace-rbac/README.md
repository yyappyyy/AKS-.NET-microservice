# Step 09: Namespace と RBAC

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- Namespace によるリソース分離を理解する
- RBAC の仕組みを理解する
- ServiceAccount の役割を理解する
- ResourceQuota / LimitRange を理解する

---

## Namespace — 実プロジェクトの例

`k8s/base/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: product-catalog
  labels:
    app.kubernetes.io/part-of: aks-microservices
```

```
AKS Cluster
├── default                    ← デフォルト（使わない方がよい）
├── kube-system                ← K8s システムコンポーネント
├── kube-public                ← 公開情報
├── product-catalog            ← ★ このプロジェクト
├── order-service              ← 将来のサービス
└── monitoring                 ← Prometheus 等
```

## RBAC の構造

```
User / ServiceAccount
        │
  RoleBinding          ← 「誰に」+「どの Role を」
        │
  Role / ClusterRole   ← 「何のリソースに」+「何ができるか」
```

| | Namespace スコープ | クラスター全体 |
|--|-------------------|--------------|
| 権限定義 | **Role** | **ClusterRole** |
| 紐づけ | **RoleBinding** | **ClusterRoleBinding** |

## ResourceQuota

Namespace ごとにリソース使用量を制限:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: kcna-lab
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    pods: "10"
```

---

## AKS ハンズオン

### 1. 既存の Namespace を確認

```bash
# クラスター内の全 Namespace を一覧表示
kubectl get namespaces
#   default       : デフォルト（ユーザーリソースの初期配置先）
#   kube-system   : K8s システムコンポーネント
#   kube-public   : 公開情報

# product-catalog Namespace の全リソースを表示
kubectl get all -n product-catalog
```

### 2. 学習用 Namespace と ResourceQuota を作成

```bash
# kcna-lab Namespace + ResourceQuota を作成
kubectl apply -f services/kcna-guide/step-09-namespace-rbac/quota.yaml

# Namespace が作成されたことを確認
kubectl get namespaces | grep kcna

# ResourceQuota の詳細を表示（Used / Hard の対比が見える）
kubectl describe resourcequota compute-quota -n kcna-lab

# kcna-lab に Pod を作ってみる（Quota の動作確認）
kubectl run test-pod --image=nginx --namespace=kcna-lab \
  --requests='cpu=100m,memory=128Mi' --limits='cpu=200m,memory=256Mi'

# Quota の Used が増えたことを確認
kubectl describe resourcequota compute-quota -n kcna-lab
```

### 🧹 クリーンアップ

```bash
# Namespace を削除すると中の全リソース（Pod, Quota 等）も一緒に消える
kubectl delete namespace kcna-lab

# 削除が完了するまで数秒かかる場合がある
# 確認
kubectl get namespaces | grep kcna
# 何も表示されなければ OK
```

---

## KCNA 試験チェックリスト

- [ ] Namespace の用途（リソース分離、環境分離）
- [ ] Role vs ClusterRole（Namespace スコープ vs クラスター全体）
- [ ] RoleBinding vs ClusterRoleBinding
- [ ] ServiceAccount = Pod が API Server にアクセスするための ID
- [ ] ResourceQuota と LimitRange の違い
