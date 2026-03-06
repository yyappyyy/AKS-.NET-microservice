# Step 12: Pod のトラブルシューティング

> **CKA 配点: Troubleshooting — 30%（最大配点！）**

## 学習目標

- Pod が起動しない原因を特定し修復できる
- CrashLoopBackOff / ImagePullBackOff / Pending の対処法
- Service に接続できない問題を解決できる

---

## Pod トラブルシューティングフロー

```
① kubectl get pods          → STATUS を確認
② kubectl describe pod      → Events を確認（原因のヒント）
③ kubectl logs pod          → アプリのエラーログ
④ kubectl logs pod --previous → 前回クラッシュ時のログ
⑤ kubectl exec pod -- sh    → コンテナ内で調査
```

---

## AKS ハンズオン

### 1. よくある Pod エラーを再現・修復

```bash
kubectl create namespace cka-trouble

# ❌ ImagePullBackOff: イメージ名が間違っている
kubectl run bad-image --image=nginx:nonexistent -n cka-trouble

# 確認
kubectl get pods -n cka-trouble
# STATUS: ErrImagePull → ImagePullBackOff

# 原因を調査
kubectl describe pod bad-image -n cka-trouble | tail -10
# Events: Failed to pull image "nginx:nonexistent"

# 修正: イメージ名を正しくする
kubectl set image pod/bad-image bad-image=nginx:1.27 -n cka-trouble
# ※ Pod は直接修正できないため、削除→再作成
kubectl delete pod bad-image -n cka-trouble
kubectl run bad-image --image=nginx:1.27 -n cka-trouble
```

### 2. CrashLoopBackOff

```bash
# ❌ コマンドが失敗する Pod
kubectl run crasher --image=busybox -n cka-trouble \
  --command -- sh -c "exit 1"

# 確認
kubectl get pods -n cka-trouble
# STATUS: CrashLoopBackOff, RESTARTS: 増加

# 原因調査
kubectl logs crasher -n cka-trouble
kubectl logs crasher -n cka-trouble --previous

# describe で Events を確認
kubectl describe pod crasher -n cka-trouble | grep -A 5 "Last State"
```

### 3. Pending（リソース不足）

```bash
# ❌ 存在しないリソースを要求する Pod
cat <<EOF | kubectl apply -n cka-trouble -f -
apiVersion: v1
kind: Pod
metadata:
  name: pending-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: "100"
        memory: "1000Gi"
EOF

# 確認
kubectl get pods -n cka-trouble
# STATUS: Pending

# 原因: Events を確認
kubectl describe pod pending-pod -n cka-trouble | grep -A 5 Events
# 0/2 nodes are available: Insufficient cpu, Insufficient memory
```

### 4. Service 接続問題のトラブルシューティング

```bash
# 正常な Pod と Service を作成
kubectl run web --image=nginx --port=80 -n cka-trouble --labels="app=web"
kubectl expose pod web --port=80 -n cka-trouble

# ① Service の Selector を確認
kubectl get svc web -n cka-trouble -o jsonpath='{.spec.selector}'

# ② Endpoints を確認（空なら紐づけに問題）
kubectl get endpoints web -n cka-trouble

# ③ Pod のラベルを確認
kubectl get pods -n cka-trouble --show-labels

# ④ Pod 内からテスト
kubectl run debug --image=busybox --rm -it -n cka-trouble -- wget -qO- --timeout=3 http://web

# ⑤ DNS を確認
kubectl run debug --image=busybox --rm -it -n cka-trouble -- nslookup web.cka-trouble.svc.cluster.local
```

### 5. 壊れた Deployment を修復

```bash
# ❌ YAML にエラーがある Deployment
cat <<EOF | kubectl apply -n cka-trouble -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-deploy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken
  template:
    metadata:
      labels:
        app: broken
    spec:
      containers:
      - name: app
        image: nginx:1.27
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /nonexistent
            port: 80
          initialDelaySeconds: 1
          periodSeconds: 2
          failureThreshold: 2
EOF

# Pod は Running だが READY=0/1（readinessProbe が /nonexistent で失敗）
kubectl get pods -n cka-trouble -l app=broken

# Endpoints が空（Pod が Ready ではないため）
kubectl get endpoints broken-deploy -n cka-trouble 2>/dev/null || echo "No endpoints"

# 修復: readinessProbe のパスを修正
kubectl edit deployment broken-deploy -n cka-trouble
# path: /nonexistent → path: /
# 保存して終了 → Pod が再作成される

# 確認
kubectl get pods -n cka-trouble -l app=broken
# READY=1/1 になれば修復完了
```

### 🧹 クリーンアップ

```bash
kubectl delete namespace cka-trouble
```

---

## CKA 試験チェックリスト

- [ ] `kubectl describe pod` → Events を最初に確認
- [ ] `kubectl logs --previous` で前回クラッシュログを確認
- [ ] ImagePullBackOff → イメージ名/タグ/レジストリ認証を確認
- [ ] CrashLoopBackOff → コマンドやアプリエラーを確認
- [ ] Pending → リソース不足/Taint/nodeSelector を確認
- [ ] Service 接続問題 → Selector, Endpoints, DNS を確認
- [ ] `kubectl edit` で稼働中のリソースを修正できる
