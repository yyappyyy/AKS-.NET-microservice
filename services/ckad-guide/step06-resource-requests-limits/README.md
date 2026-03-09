# Step 06: Resource Requests / Limits と Probes

## 学習目標

- `requests` と `limits` の違いを理解し、適切に設定できる
- `LimitRange` / `ResourceQuota` でリソースを制限できる
- `livenessProbe` / `readinessProbe` / `startupProbe` を設定できる
- Probe の失敗による Pod 再起動の挙動を理解する

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-resources
```

## 2. Resource Requests / Limits の設定

```yaml
# resource-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
  namespace: ckad-resources
spec:
  containers:
  - name: app
    image: nginx:1.27
    resources:
      requests:
        cpu: 50m         # 0.05 CPU (最低保証)
        memory: 64Mi     # 64 MiB (最低保証)
      limits:
        cpu: 200m        # 0.2 CPU (上限)
        memory: 128Mi    # 128 MiB (上限)
    ports:
    - containerPort: 80
```

```bash
kubectl apply -f resource-pod.yaml

# リソース設定を確認
kubectl describe pod resource-demo -n ckad-resources | grep -A 5 "Limits\|Requests"

# 実際のリソース使用量
kubectl top pod resource-demo -n ckad-resources 2>/dev/null || echo "metrics-server が必要です"
```

## 3. LimitRange — デフォルト制限

```yaml
# limit-range.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: ckad-resources
spec:
  limits:
  - type: Container
    default:          # limits のデフォルト
      cpu: 200m
      memory: 256Mi
    defaultRequest:   # requests のデフォルト
      cpu: 50m
      memory: 64Mi
    max:
      cpu: "1"
      memory: 512Mi
    min:
      cpu: 10m
      memory: 16Mi
```

```bash
kubectl apply -f limit-range.yaml
kubectl describe limitrange default-limits -n ckad-resources

# リソース未指定で Pod を作成 → デフォルト値が適用される
kubectl run no-resource-pod --image=nginx:1.27 -n ckad-resources
kubectl describe pod no-resource-pod -n ckad-resources | grep -A 5 "Limits\|Requests"
```

## 4. ResourceQuota — Namespace レベルの制限

```yaml
# resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-quota
  namespace: ckad-resources
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 1Gi
    limits.cpu: "4"
    limits.memory: 2Gi
    pods: "10"
    configmaps: "5"
```

```bash
kubectl apply -f resource-quota.yaml

# 使用状況を確認
kubectl get resourcequota ns-quota -n ckad-resources
kubectl describe resourcequota ns-quota -n ckad-resources
```

## 5. Liveness Probe — コンテナの死活監視

```yaml
# liveness-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
  namespace: ckad-resources
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "App starting..."
      touch /tmp/healthy
      echo "Health file created"
      sleep 20
      echo "Removing health file (simulating failure)..."
      rm -f /tmp/healthy
      sleep 600
    livenessProbe:
      exec:
        command: ["cat", "/tmp/healthy"]
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
```

```bash
kubectl apply -f liveness-pod.yaml

# 最初は正常、20秒後に probe 失敗 → 再起動
kubectl get pod liveness-demo -n ckad-resources -w

# イベントで再起動理由を確認
kubectl describe pod liveness-demo -n ckad-resources | grep -A 10 "Events"

# 再起動回数を確認
kubectl get pod liveness-demo -n ckad-resources
```

## 6. Readiness Probe — トラフィック受信可否

```yaml
# readiness-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-demo
  namespace: ckad-resources
  labels:
    app: readiness-app
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 5
      failureThreshold: 2
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
      failureThreshold: 3
```

```bash
kubectl apply -f readiness-pod.yaml

# READY 状態を確認
kubectl get pod readiness-demo -n ckad-resources

# Probe の設定確認
kubectl describe pod readiness-demo -n ckad-resources | grep -A 5 "Liveness\|Readiness"
```

## 7. Startup Probe — 起動が遅いアプリ向け

```yaml
# startup-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-demo
  namespace: ckad-resources
spec:
  containers:
  - name: slow-app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "Slow startup simulation..."
      sleep 15
      echo "ready" > /tmp/started
      echo "App is ready!"
      while true; do sleep 10; done
    startupProbe:
      exec:
        command: ["cat", "/tmp/started"]
      failureThreshold: 10     # 10 回まで待つ
      periodSeconds: 3         # 3 秒ごとにチェック → 最大 30 秒
    livenessProbe:
      exec:
        command: ["cat", "/tmp/started"]
      periodSeconds: 10
```

```bash
kubectl apply -f startup-pod.yaml

# startupProbe が成功するまで READY にならない
kubectl get pod startup-demo -n ckad-resources -w

# 約 15 秒後に READY になる
kubectl describe pod startup-demo -n ckad-resources
```

## 8. TCP Probe

```yaml
# tcp-probe-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tcp-probe-demo
  namespace: ckad-resources
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    readinessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 5
    livenessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
```

```bash
kubectl apply -f tcp-probe-pod.yaml
kubectl get pod tcp-probe-demo -n ckad-resources
kubectl describe pod tcp-probe-demo -n ckad-resources | grep -A 3 "Liveness\|Readiness"
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-resources
```
