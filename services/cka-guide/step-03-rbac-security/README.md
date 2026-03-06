# Step 03: RBAC とセキュリティ

> **CKA 配点: Cluster Architecture — 25%**

## 学習目標

- RBAC の Role / ClusterRole / Binding を作成・管理できる
- ServiceAccount を Pod に割り当てられる
- NetworkPolicy でトラフィックを制御できる
- SecurityContext を設定できる

---

## RBAC 構造の復習

```
Subject（誰）          Binding（紐づけ）        Role（権限）
┌──────────┐         ┌─────────────┐        ┌──────────┐
│ User     │────────▶│ RoleBinding │───────▶│ Role     │
│ Group    │         │ (NS scope)  │        │ (NS scope)│
│ SA       │         └─────────────┘        └──────────┘
│          │         ┌─────────────┐        ┌──────────┐
│          │────────▶│ClusterRole  │───────▶│ClusterRole│
│          │         │  Binding    │        │ (cluster) │
└──────────┘         └─────────────┘        └──────────┘
```

---

## AKS ハンズオン

### 1. Role と RoleBinding を作成

```bash
# 学習用 Namespace を作成
kubectl create namespace cka-rbac

# ① Role を作成（pods の get/list/watch のみ許可）
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  --namespace=cka-rbac

# 確認
kubectl describe role pod-reader -n cka-rbac

# ② RoleBinding を作成（developer ユーザーに pod-reader を紐づけ）
kubectl create rolebinding dev-pod-reader \
  --role=pod-reader \
  --user=developer \
  --namespace=cka-rbac

# 確認
kubectl describe rolebinding dev-pod-reader -n cka-rbac

# ③ 権限テスト
kubectl auth can-i get pods --namespace=cka-rbac --as=developer
# yes

kubectl auth can-i delete pods --namespace=cka-rbac --as=developer
# no

kubectl auth can-i get pods --namespace=default --as=developer
# no（cka-rbac Namespace の権限しかないため）
```

### 2. ClusterRole と ClusterRoleBinding

```bash
# ClusterRole を作成（全 Namespace で nodes を参照可能）
kubectl create clusterrole node-viewer \
  --verb=get,list \
  --resource=nodes

# ClusterRoleBinding で紐づけ
kubectl create clusterrolebinding ops-node-viewer \
  --clusterrole=node-viewer \
  --user=ops-user

# 権限テスト
kubectl auth can-i list nodes --as=ops-user
# yes

# YAML を生成して確認
kubectl create role web-role --verb=get,list,create,delete \
  --resource=pods,services,deployments --namespace=cka-rbac \
  --dry-run=client -o yaml
```

### 3. ServiceAccount を作成して Pod に割り当て

```bash
# ServiceAccount を作成
kubectl create serviceaccount app-sa -n cka-rbac

# SA に Role を紐づけ
kubectl create rolebinding app-sa-binding \
  --role=pod-reader \
  --serviceaccount=cka-rbac:app-sa \
  --namespace=cka-rbac

# SA を使った Pod を作成
kubectl run sa-test --image=nginx -n cka-rbac \
  --overrides='{"spec":{"serviceAccountName":"app-sa"}}'

# Pod の ServiceAccount を確認
kubectl get pod sa-test -n cka-rbac -o jsonpath='{.spec.serviceAccountName}'
# app-sa
```

### 4. NetworkPolicy

```bash
# テスト用 Pod を作成
kubectl run web --image=nginx --port=80 -n cka-rbac --labels="app=web"
kubectl expose pod web --port=80 -n cka-rbac
kubectl run client --image=busybox -n cka-rbac --labels="app=client" --command -- sleep 3600

# 通信確認（NetworkPolicy なし → 許可）
kubectl exec client -n cka-rbac -- wget -qO- --timeout=3 http://web
# → nginx のHTMLが表示される

# NetworkPolicy を作成（web Pod へは app=client からのみ許可）
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-only
  namespace: cka-rbac
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: client
    ports:
    - port: 80
EOF

# client からはアクセスできる
kubectl exec client -n cka-rbac -- wget -qO- --timeout=3 http://web

# 別ラベルの Pod からはブロックされる
kubectl run blocked --image=busybox -n cka-rbac --command -- sleep 3600
kubectl exec blocked -n cka-rbac -- wget -qO- --timeout=3 http://web 2>&1 || echo "BLOCKED"
```

### 5. SecurityContext

```bash
# non-root で実行する Pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: cka-rbac
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "id && sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
EOF

# ユーザー確認
kubectl logs secure-pod -n cka-rbac
# uid=1000 gid=3000 groups=2000
```

### 🧹 クリーンアップ

```bash
kubectl delete namespace cka-rbac
kubectl delete clusterrole node-viewer --ignore-not-found
kubectl delete clusterrolebinding ops-node-viewer --ignore-not-found
```

---

## CKA 試験チェックリスト

- [ ] `kubectl create role` / `kubectl create rolebinding` をスラスラ書ける
- [ ] `kubectl auth can-i --as=<user>` で権限をテストできる
- [ ] ServiceAccount を Pod に割り当てられる
- [ ] NetworkPolicy を書ける（Ingress / Egress）
- [ ] SecurityContext の runAsUser, readOnlyRootFilesystem を設定できる
