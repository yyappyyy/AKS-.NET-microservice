# Step 10: SecurityContext と ServiceAccount

## 学習目標

- Pod / Container レベルの SecurityContext を設定できる
- `runAsUser`, `runAsNonRoot`, `readOnlyRootFilesystem` の効果を理解する
- ServiceAccount を作成し Pod に割り当てられる
- `automountServiceAccountToken` の制御を理解する

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-sec
```

## 2. SecurityContext — runAsUser / runAsGroup

```yaml
# secctx-user.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secctx-user
  namespace: ckad-sec
spec:
  securityContext:
    runAsUser: 1000        # UID 1000 で実行
    runAsGroup: 3000       # GID 3000
    fsGroup: 2000          # Volume の所有グループ
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "id && ls -la /data && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
```

```bash
kubectl apply -f secctx-user.yaml

# UID/GID を確認
kubectl exec secctx-user -n ckad-sec -- id
# uid=1000 gid=3000 groups=2000

# Volume の所有グループが fsGroup (2000) になっている
kubectl exec secctx-user -n ckad-sec -- ls -la /data
```

## 3. SecurityContext — runAsNonRoot

```yaml
# secctx-nonroot.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secctx-nonroot
  namespace: ckad-sec
spec:
  securityContext:
    runAsNonRoot: true       # root 実行を拒否
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "id && whoami && sleep 3600"]
    securityContext:
      runAsUser: 1000
```

```bash
kubectl apply -f secctx-nonroot.yaml
kubectl exec secctx-nonroot -n ckad-sec -- id
kubectl exec secctx-nonroot -n ckad-sec -- whoami
```

### root で起動しようとすると失敗するテスト

```yaml
# secctx-nonroot-fail.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secctx-root-fail
  namespace: ckad-sec
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    # runAsUser を指定しない → デフォルト root → 起動失敗
```

```bash
kubectl apply -f secctx-nonroot-fail.yaml

# エラーで起動できない
kubectl get pod secctx-root-fail -n ckad-sec
kubectl describe pod secctx-root-fail -n ckad-sec | grep -A 3 "Error\|Warning"
```

## 4. SecurityContext — readOnlyRootFilesystem

```yaml
# secctx-readonly.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secctx-readonly
  namespace: ckad-sec
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "Try writing to root fs..."
      touch /test.txt 2>&1 || echo "BLOCKED: Root fs is read-only!"
      echo "Writing to writable volume..."
      echo "OK" > /tmp/test.txt && echo "SUCCESS: /tmp is writable"
      cat /tmp/test.txt
      sleep 3600
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

```bash
kubectl apply -f secctx-readonly.yaml
kubectl logs secctx-readonly -n ckad-sec

# Root fs への書き込みは失敗、/tmp は OK
kubectl exec secctx-readonly -n ckad-sec -- touch /fail.txt 2>&1 || echo "Blocked as expected"
kubectl exec secctx-readonly -n ckad-sec -- cat /tmp/test.txt
```

## 5. SecurityContext — capabilities

```yaml
# secctx-caps.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secctx-caps
  namespace: ckad-sec
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      capabilities:
        drop:
        - ALL                # 全 capability を削除
        add:
        - NET_BIND_SERVICE   # ポート 1024 未満でバインド可能
```

```bash
kubectl apply -f secctx-caps.yaml
kubectl describe pod secctx-caps -n ckad-sec | grep -A 5 "Capabilities"
```

## 6. ServiceAccount の作成

```bash
# ServiceAccount 作成
kubectl create serviceaccount app-sa -n ckad-sec
kubectl get serviceaccounts -n ckad-sec

# ServiceAccount の詳細
kubectl describe serviceaccount app-sa -n ckad-sec
```

## 7. Pod に ServiceAccount を割り当て

```yaml
# sa-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: sa-demo
  namespace: ckad-sec
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: true
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "ServiceAccount token:"
      cat /var/run/secrets/kubernetes.io/serviceaccount/token | head -c 50
      echo "..."
      echo ""
      echo "Namespace:"
      cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
      echo ""
      sleep 3600
```

```bash
kubectl apply -f sa-pod.yaml

# ServiceAccount 情報を Pod 内で確認
kubectl exec sa-demo -n ckad-sec -- cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
kubectl exec sa-demo -n ckad-sec -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```

## 8. automountServiceAccountToken を無効化

```yaml
# sa-no-mount.yaml
apiVersion: v1
kind: Pod
metadata:
  name: sa-no-mount
  namespace: ckad-sec
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false    # トークンをマウントしない
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "ls /var/run/secrets/ 2>&1 || echo 'No secrets mounted'; sleep 3600"]
```

```bash
kubectl apply -f sa-no-mount.yaml
kubectl logs sa-no-mount -n ckad-sec
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-sec
```
