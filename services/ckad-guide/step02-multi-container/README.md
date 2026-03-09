# Step 02: マルチコンテナ Pod

## 学習目標

- Sidecar / Ambassador / Adapter パターンを理解する
- 1 つの Pod に複数コンテナを配置して連携させる
- `kubectl logs -c` で特定コンテナのログを取得できる
- Init Container の役割と書き方を理解する

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-multi
```

## 2. Sidecar パターン — ログ収集

メインコンテナがログを出力し、サイドカーがそのログを読む構成。

```yaml
# sidecar-logging.yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-logging
  namespace: ckad-multi
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      i=0
      while true; do
        echo "$(date) - Log entry $i from app container" >> /var/log/app.log
        i=$((i+1))
        sleep 3
      done
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "tail -f /var/log/app.log"]
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  volumes:
  - name: log-volume
    emptyDir: {}
```

```bash
kubectl apply -f sidecar-logging.yaml

# メインコンテナのログ (stdout には出ない)
kubectl logs sidecar-logging -n ckad-multi -c app

# サイドカーのログ (ファイルを tail しているので表示される)
kubectl logs sidecar-logging -n ckad-multi -c sidecar
kubectl logs sidecar-logging -n ckad-multi -c sidecar --tail=5

# 全コンテナのログ
kubectl logs sidecar-logging -n ckad-multi --all-containers=true
```

## 3. Ambassador パターン — プロキシ

メインコンテナが localhost 経由でアンバサダーコンテナ (プロキシ) にアクセスする構成。

```yaml
# ambassador.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ambassador-demo
  namespace: ckad-multi
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      while true; do
        echo "--- $(date) ---"
        wget -qO- http://localhost:80 2>/dev/null || echo "waiting for proxy..."
        sleep 5
      done
  - name: proxy
    image: nginx:1.27
    ports:
    - containerPort: 80
```

```bash
kubectl apply -f ambassador.yaml

# app コンテナが nginx (proxy) から応答を得ているか確認
kubectl logs ambassador-demo -n ckad-multi -c app --tail=10

# proxy コンテナのログ
kubectl logs ambassador-demo -n ckad-multi -c proxy
```

## 4. Adapter パターン — データ変換

メインコンテナの出力を Adapter コンテナが変換する構成。

```yaml
# adapter.yaml
apiVersion: v1
kind: Pod
metadata:
  name: adapter-demo
  namespace: ckad-multi
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      while true; do
        echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"INFO\",\"msg\":\"heartbeat\"}" >> /var/log/app.json
        sleep 5
      done
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  - name: adapter
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      touch /var/log/app.json
      tail -f /var/log/app.json | while read line; do
        echo "$line" | sed 's/INFO/✅ INFO/g'
      done
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  volumes:
  - name: log-volume
    emptyDir: {}
```

```bash
kubectl apply -f adapter.yaml

# adapter が変換したログを確認
kubectl logs adapter-demo -n ckad-multi -c adapter --tail=5
```

## 5. Init Container

メインコンテナの起動前に初期化処理を行うコンテナ。

```yaml
# init-container.yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
  namespace: ckad-multi
spec:
  initContainers:
  - name: init-setup
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "=== Init Container Start ==="
      echo "<h1>Page prepared by Init Container at $(date)</h1>" > /work/index.html
      echo "=== Init Container Done ==="
      sleep 2
  - name: init-check
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "Checking if index.html exists..."
      if [ -f /work/index.html ]; then
        echo "OK: File found"
      else
        echo "ERROR: File not found" && exit 1
      fi
    volumeMounts:
    - name: workdir
      mountPath: /work
  containers:
  - name: web
    image: nginx:1.27
    ports:
    - containerPort: 80
    volumeMounts:
    - name: workdir
      mountPath: /usr/share/nginx/html
  volumes:
  - name: workdir
    emptyDir: {}
```

> ⚠ 上の `init-setup` にも `volumeMounts` が必要です:

```yaml
  initContainers:
  - name: init-setup
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "<h1>Page prepared by Init Container at $(date)</h1>" > /work/index.html
    volumeMounts:
    - name: workdir
      mountPath: /work
```

```bash
kubectl apply -f init-container.yaml

# Init Container の状態確認
kubectl get pod init-demo -n ckad-multi
kubectl describe pod init-demo -n ckad-multi

# Init Container のログ
kubectl logs init-demo -n ckad-multi -c init-setup
kubectl logs init-demo -n ckad-multi -c init-check

# メインコンテナの動作確認
kubectl exec init-demo -n ckad-multi -- curl -s localhost
```

## 6. 特定コンテナでコマンド実行

```bash
# -c で対象コンテナを指定
kubectl exec -it sidecar-logging -n ckad-multi -c app -- /bin/sh
# (シェル内で)
cat /var/log/app.log | tail -3
exit

kubectl exec -it sidecar-logging -n ckad-multi -c sidecar -- /bin/sh
# (シェル内で)
ls /var/log/
exit
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-multi
```
