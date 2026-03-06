# Step 06: 高度なスケジューリング

> **CKA 配点: Workloads & Scheduling — 15%**

## 学習目標

- nodeSelector, Node Affinity, Pod Affinity/Anti-Affinity を設定できる
- Taint / Toleration を使って Pod の配置を制御できる
- Pod のプライオリティとプリエンプションを理解する

---

## AKS ハンズオン

### 1. nodeSelector

```bash
kubectl create namespace cka-sched

# Node のラベルを確認
kubectl get nodes --show-labels

# Node にラベルを追加
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl label nodes $NODE disktype=ssd

# nodeSelector で配置制御
cat <<EOF | kubectl apply -n cka-sched -f -
apiVersion: v1
kind: Pod
metadata:
  name: ssd-pod
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: app
    image: nginx
EOF

# Pod が指定 Node に配置されたか確認
kubectl get pod ssd-pod -n cka-sched -o wide
```

### 2. Node Affinity

```bash
# required（必須条件）
cat <<EOF | kubectl apply -n cka-sched -f -
apiVersion: v1
kind: Pod
metadata:
  name: affinity-required
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
            - nvme
  containers:
  - name: app
    image: nginx
EOF

# preferred（優先条件）
cat <<EOF | kubectl apply -n cka-sched -f -
apiVersion: v1
kind: Pod
metadata:
  name: affinity-preferred
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
  containers:
  - name: app
    image: nginx
EOF

kubectl get pods -n cka-sched -o wide
```

### 3. Taint と Toleration

```bash
# Node に Taint を追加
kubectl taint nodes $NODE dedicated=special:NoSchedule

# Toleration なしの Pod → Pending になる
kubectl run no-tol --image=nginx -n cka-sched
kubectl get pod no-tol -n cka-sched
# STATUS: Pending

# Toleration ありの Pod → 配置される
cat <<EOF | kubectl apply -n cka-sched -f -
apiVersion: v1
kind: Pod
metadata:
  name: with-tol
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "special"
    effect: "NoSchedule"
  containers:
  - name: app
    image: nginx
EOF

kubectl get pod with-tol -n cka-sched -o wide

# Taint を削除（末尾に -）
kubectl taint nodes $NODE dedicated=special:NoSchedule-
```

### 4. Pod Affinity / Anti-Affinity

```bash
# フロントエンドとバックエンドを同じ Node に配置（Affinity）
kubectl run backend --image=nginx -n cka-sched --labels="app=backend"

cat <<EOF | kubectl apply -n cka-sched -f -
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: backend
        topologyKey: kubernetes.io/hostname
  containers:
  - name: app
    image: nginx
EOF

# 同じ Node に配置されたか確認
kubectl get pods -n cka-sched -o wide
```

### 🧹 クリーンアップ

```bash
kubectl delete namespace cka-sched
kubectl label nodes $NODE disktype-
# Taint が残っている場合: kubectl taint nodes $NODE dedicated=special:NoSchedule-
```

---

## CKA 試験チェックリスト

- [ ] nodeSelector を設定できる
- [ ] Node Affinity の required/preferred を YAML で書ける
- [ ] Taint を追加/削除できる（`kubectl taint`）
- [ ] Toleration を Pod に書ける
- [ ] Pod Affinity/Anti-Affinity の topologyKey を理解している
