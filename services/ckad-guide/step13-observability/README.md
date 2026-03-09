# Step 13: ログ・メトリクス・デバッグ

## 学習目標

- `kubectl logs` のオプションを使いこなす
- `kubectl top` でリソース使用量を確認できる
- `kubectl debug` で Pod をデバッグできる
- トラブルシューティングの手順を理解する

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-obs
```

## 2. テスト用 Pod を作成

```yaml
# logging-app.yaml
apiVersion: v1
kind: Pod
metadata:
  name: logging-app
  namespace: ckad-obs
  labels:
    app: logging-demo
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      i=0
      while true; do
        level="INFO"
        if [ $((i % 10)) -eq 0 ]; then level="ERROR"; fi
        if [ $((i % 5)) -eq 0 ]; then level="WARN"; fi
        echo "$(date -Iseconds) [$level] Message $i from $(hostname)"
        i=$((i+1))
        sleep 2
      done
```

```bash
kubectl apply -f logging-app.yaml
```

## 3. kubectl logs のオプション

```bash
# 基本的なログ表示
kubectl logs logging-app -n ckad-obs

# 末尾 10 行
kubectl logs logging-app -n ckad-obs --tail=10

# リアルタイム追跡
kubectl logs logging-app -n ckad-obs -f --tail=5  # Ctrl+C で終了

# 直近 1 分のログ
kubectl logs logging-app -n ckad-obs --since=1m

# 直近 30 秒のログ
kubectl logs logging-app -n ckad-obs --since=30s

# タイムスタンプ付き
kubectl logs logging-app -n ckad-obs --timestamps=true --tail=5

# 前回のコンテナのログ (再起動後)
kubectl logs logging-app -n ckad-obs --previous 2>/dev/null || echo "No previous container"

# ラベルで複数 Pod のログ
kubectl logs -l app=logging-demo -n ckad-obs --prefix --tail=3
```

## 4. grep でログをフィルタリング

```bash
# ERROR だけ抽出
kubectl logs logging-app -n ckad-obs | grep "ERROR"

# WARN 以上を抽出
kubectl logs logging-app -n ckad-obs | grep -E "ERROR|WARN"

# 直近 2 分の ERROR をカウント
kubectl logs logging-app -n ckad-obs --since=2m | grep -c "ERROR"
```

## 5. マルチコンテナ Pod のログ

```yaml
# multi-log.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-log
  namespace: ckad-obs
spec:
  containers:
  - name: web
    image: nginx:1.27
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo 'Sidecar heartbeat'; sleep 5; done"]
```

```bash
kubectl apply -f multi-log.yaml

# コンテナ指定
kubectl logs multi-log -n ckad-obs -c web
kubectl logs multi-log -n ckad-obs -c sidecar --tail=3

# 全コンテナのログ (プレフィックス付き)
kubectl logs multi-log -n ckad-obs --all-containers --prefix --tail=5
```

## 6. kubectl top — リソース使用量

```bash
# Pod のリソース使用量
kubectl top pods -n ckad-obs

# 全 Namespace
kubectl top pods --all-namespaces --sort-by=memory | head -20

# Node のリソース使用量
kubectl top nodes

# コンテナ単位
kubectl top pods -n ckad-obs --containers
```

## 7. kubectl debug — Pod デバッグ

```bash
# ephemeral container でデバッグ
kubectl debug -it logging-app -n ckad-obs --image=busybox:1.36 --target=app

# (デバッグコンテナ内で)
# ps aux              # プロセス確認
# ls /proc/1/cwd      # メインプロセスの作業ディレクトリ
# exit

# Pod のコピーを作成してデバッグ
kubectl debug logging-app -n ckad-obs --copy-to=debug-copy \
  --image=busybox:1.36 -it -- /bin/sh
# exit
kubectl delete pod debug-copy -n ckad-obs
```

## 8. トラブルシューティング手順

### Pod が起動しない場合

```bash
# 1. Pod の状態確認
kubectl get pods -n ckad-obs

# 2. イベント確認
kubectl describe pod <pod-name> -n ckad-obs

# 3. ログ確認
kubectl logs <pod-name> -n ckad-obs

# 4. よくある原因を確認
kubectl get events -n ckad-obs --sort-by=.lastTimestamp | tail -10
```

### CrashLoopBackOff のテスト

```yaml
# crash-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: crash-demo
  namespace: ckad-obs
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'Starting...' && exit 1"]
```

```bash
kubectl apply -f crash-pod.yaml

# CrashLoopBackOff の状態を確認
kubectl get pod crash-demo -n ckad-obs -w  # Ctrl+C で停止

# ログで原因を調査
kubectl logs crash-demo -n ckad-obs
kubectl logs crash-demo -n ckad-obs --previous

# イベントで詳細を確認
kubectl describe pod crash-demo -n ckad-obs | tail -20
```

### ImagePullBackOff のテスト

```bash
# 存在しないイメージを指定
kubectl run bad-image --image=nginx:nonexistent -n ckad-obs

# エラー確認
kubectl get pod bad-image -n ckad-obs
kubectl describe pod bad-image -n ckad-obs | grep -A 5 "Events"
```

## 9. kubectl get events

```bash
# Namespace のイベント (時系列)
kubectl get events -n ckad-obs --sort-by=.lastTimestamp

# Warning のみ
kubectl get events -n ckad-obs --field-selector type=Warning

# 全 Namespace
kubectl get events --all-namespaces --sort-by=.lastTimestamp | tail -20
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-obs
```
