# Step 05: ワークロード管理

> **CKA 配点: Workloads & Scheduling — 15%**

## 学習目標

- Deployment の作成・更新・スケールを即座に実行できる
- Pod のマニフェストを素早く作成できる
- マルチコンテナ Pod を構成できる
- ロールアウト管理ができる

---

## CKA 試験のためのスピードテクニック

### YAML を素早く生成する

```bash
# Pod の YAML 雛形（--dry-run=client -o yaml が重要！）
kubectl run nginx --image=nginx --port=80 \
  --dry-run=client -o yaml > pod.yaml

# Deployment の YAML 雛形
kubectl create deployment web --image=nginx --replicas=3 \
  --dry-run=client -o yaml > deploy.yaml

# Service の YAML 雛形
kubectl expose deployment web --port=80 --target-port=8080 \
  --dry-run=client -o yaml > svc.yaml

# Job の YAML 雛形
kubectl create job backup --image=busybox \
  -- sh -c "echo backup done" \
  --dry-run=client -o yaml > job.yaml

# CronJob
kubectl create cronjob daily-backup --image=busybox \
  --schedule="0 2 * * *" \
  -- sh -c "echo daily backup" \
  --dry-run=client -o yaml > cronjob.yaml
```

---

## AKS ハンズオン

### 1. Pod を素早く作成・変更する

```bash
# Namespace 作成
kubectl create namespace cka-workloads

# Pod を Imperative に作成
kubectl run web --image=nginx --port=80 -n cka-workloads

# Pod のラベルを追加
kubectl label pod web app=frontend -n cka-workloads

# Pod のラベルを変更
kubectl label pod web app=backend --overwrite -n cka-workloads

# Pod にアノテーションを追加
kubectl annotate pod web description="CKA practice" -n cka-workloads

# 確認
kubectl get pod web -n cka-workloads --show-labels
kubectl describe pod web -n cka-workloads | head -20
```

### 2. Deployment の作成とロールアウト

```bash
# Deployment 作成
kubectl create deployment web-app --image=nginx:1.27 --replicas=3 -n cka-workloads

# ロールアウト状態の確認
kubectl rollout status deployment web-app -n cka-workloads

# イメージの更新（ローリングアップデート）
kubectl set image deployment web-app nginx=nginx:1.28 -n cka-workloads

# 変更理由を記録（--record は非推奨だが CHANGE-CAUSE に記載される）
kubectl annotate deployment web-app -n cka-workloads \
  kubernetes.io/change-cause="Updated to nginx 1.28"

# ロールアウト履歴
kubectl rollout history deployment web-app -n cka-workloads

# ロールバック
kubectl rollout undo deployment web-app -n cka-workloads

# 一時停止と再開（複数変更をまとめたい時）
kubectl rollout pause deployment web-app -n cka-workloads
kubectl set image deployment web-app nginx=nginx:1.29 -n cka-workloads
kubectl set resources deployment web-app -c nginx --requests=cpu=100m,memory=128Mi -n cka-workloads
kubectl rollout resume deployment web-app -n cka-workloads
```

### 3. マルチコンテナ Pod

```bash
# Sidecar パターンの Pod
cat <<EOF | kubectl apply -n cka-workloads -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-container
spec:
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  - name: sidecar
    image: busybox
    command: ["sh", "-c", "while true; do date >> /html/index.html; sleep 5; done"]
    volumeMounts:
    - name: shared
      mountPath: /html
  volumes:
  - name: shared
    emptyDir: {}
EOF

# 各コンテナのログを確認（-c でコンテナ名を指定）
kubectl logs multi-container -n cka-workloads -c app
kubectl logs multi-container -n cka-workloads -c sidecar

# Init Container 付き Pod
cat <<EOF | kubectl apply -n cka-workloads -f -
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  initContainers:
  - name: init-wait
    image: busybox
    command: ["sh", "-c", "echo Init done!; sleep 3"]
  containers:
  - name: app
    image: nginx
EOF

# Init Container の完了を確認
kubectl get pod init-demo -n cka-workloads
kubectl describe pod init-demo -n cka-workloads | grep -A 5 "Init Containers"
```

### 4. リソース制限の設定

```bash
# Deployment にリソース制限を Imperative に設定
kubectl set resources deployment web-app -n cka-workloads \
  -c nginx \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=250m,memory=256Mi

# 確認
kubectl get deployment web-app -n cka-workloads -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq .
```

### 🧹 クリーンアップ

```bash
kubectl delete namespace cka-workloads
```

---

## CKA 試験チェックリスト

- [ ] `--dry-run=client -o yaml` で YAML を即座に生成できる
- [ ] `kubectl set image` でローリングアップデートできる
- [ ] `kubectl rollout undo` でロールバックできる
- [ ] `kubectl rollout pause/resume` で複数変更をまとめられる
- [ ] マルチコンテナ Pod の YAML を書ける
- [ ] Init Container の YAML を書ける
- [ ] `kubectl set resources` でリソース制限を設定できる
