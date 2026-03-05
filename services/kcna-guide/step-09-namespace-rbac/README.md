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

### Namespace で何が分離されるか

```
AKS Cluster
├── default           ← デフォルト（使わない方がよい）
├── kube-system       ← K8s システムコンポーネント
├── kube-public       ← 公開情報
├── product-catalog   ← ★ このプロジェクト
└── monitoring        ← Prometheus 等
```

| | Namespace スコープ | クラスタースコープ |
|--|-------------------|------------------|
| 例 | Pod, Service, Deployment, ConfigMap, Secret, Role | Node, PV, ClusterRole, Namespace 自体 |

---

## RBAC の構造

```
User / Group / ServiceAccount   ← 「誰が」
        │
  RoleBinding / ClusterRoleBinding   ← 「紐づけ」
        │
  Role / ClusterRole   ← 「何に」+「何ができるか」
```

| | Namespace スコープ | クラスター全体 |
|--|-------------------|--------------|
| 権限定義 | **Role** | **ClusterRole** |
| 紐づけ | **RoleBinding** | **ClusterRoleBinding** |

### Role の例

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: product-catalog
  name: pod-reader
rules:
  - apiGroups: [""]            # core API グループ
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

### ServiceAccount

Pod が API Server にアクセスするための **ID**:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: product-catalog
```

---

## ResourceQuota と LimitRange

| リソース | 対象 | 説明 |
|----------|------|------|
| **ResourceQuota** | Namespace 全体 | NS 内のリソース使用量の合計上限 |
| **LimitRange** | 個々の Pod | Pod ごとのデフォルト値や最大値 |

---

## AKS ハンズオン

### 1. Namespace を確認

```bash
# 全 Namespace 一覧
kubectl get namespaces

# Namespace の詳細
kubectl describe namespace default

# product-catalog の全リソース
kubectl get all -n product-catalog

# Namespace スコープのリソースだけ表示
kubectl api-resources --namespaced=true | head -20

# クラスタースコープのリソースだけ表示
kubectl api-resources --namespaced=false | head -20
```

### 2. 学習用 Namespace + ResourceQuota を作成

```bash
# kcna-lab Namespace + Quota を作成
kubectl apply -f services/kcna-guide/step-09-namespace-rbac/quota.yaml

# 確認
kubectl get namespaces | grep kcna

# Quota の詳細（Used / Hard の対比）
kubectl describe resourcequota compute-quota -n kcna-lab
```

### 3. Quota の動作を体験

```bash
# Pod を作成（requests/limits 必須）
kubectl run test-pod --image=nginx --namespace=kcna-lab \
  --requests='cpu=100m,memory=128Mi' --limits='cpu=200m,memory=256Mi'

# Quota の Used が増える
kubectl describe resourcequota compute-quota -n kcna-lab

# requests/limits なしで作ろうとすると → Quota のため拒否される
kubectl run test-pod2 --image=nginx --namespace=kcna-lab 2>&1 || true
# Error: failed quota: compute-quota
```

### 4. RBAC を確認

```bash
# 現在のユーザーの権限を確認
kubectl auth can-i create pods
kubectl auth can-i delete deployments
kubectl auth can-i create pods --namespace=kube-system

# 全ての権限を確認
kubectl auth can-i --list

# ClusterRole 一覧（K8s 組み込みの Role が多数）
kubectl get clusterrole | head -20

# admin ClusterRole の詳細
kubectl describe clusterrole admin | head -30

# ServiceAccount 一覧
kubectl get serviceaccount -n kcna-lab
kubectl get serviceaccount -n kube-system | head -10

# default ServiceAccount の詳細
kubectl describe serviceaccount default -n kcna-lab
```

### 5. Namespace の操作

```bash
# Imperative に Namespace を作成
kubectl create namespace test-ns

# デフォルト Namespace を変更（毎回 -n を付けなくてよくなる）
kubectl config set-context --current --namespace=test-ns

# 確認
kubectl config view --minify | grep namespace

# default に戻す
kubectl config set-context --current --namespace=default

# Namespace を削除
kubectl delete namespace test-ns
```

### 🧹 クリーンアップ

```bash
# Namespace を削除（中の全リソースも一緒に消える）
kubectl delete namespace kcna-lab

# 確認
kubectl get namespaces | grep kcna
```

---

## KCNA 試験チェックリスト

- [ ] Namespace の用途（リソース分離、チーム分離、環境分離）
- [ ] Namespace スコープ vs クラスタースコープ
- [ ] Role vs ClusterRole
- [ ] RoleBinding vs ClusterRoleBinding
- [ ] ServiceAccount = Pod の API アクセス用 ID
- [ ] ResourceQuota（NS全体）と LimitRange（Pod個別）の違い
- [ ] 最小権限の原則
