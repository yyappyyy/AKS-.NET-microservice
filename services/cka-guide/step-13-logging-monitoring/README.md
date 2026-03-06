# Step 13: ロギングとモニタリング

> **CKA 配点: Troubleshooting — 30%（最大配点！）**

## 学習目標

- Pod / Node のリソース使用量を確認できる
- コンテナログを効率的に確認できる
- クラスターイベントを監視できる
- リソース使用量に基づくトラブルシューティングができる

---

## AKS ハンズオン

### 1. 準備: テスト用リソースを作成

```bash
kubectl create namespace cka-monitor

# CPU を消費する Pod を作成（モニタリングのテスト用）
kubectl run cpu-burner --image=busybox -n cka-monitor \
  --requests='cpu=50m,memory=64Mi' --limits='cpu=100m,memory=128Mi' \
  --command -- sh -c "while true; do :; done"

# 通常の Pod を複数作成
kubectl create deployment log-test --image=nginx --replicas=3 -n cka-monitor
kubectl expose deployment log-test --port=80 -n cka-monitor

# ログを出力する Pod
kubectl run log-producer --image=busybox -n cka-monitor \
  --command -- sh -c 'i=0; while true; do echo "[$(date)] Log entry $i"; i=$((i+1)); sleep 2; done'

# 起動確認
kubectl get pods -n cka-monitor
```

### 2. Node のリソース使用量

```bash
# Node の CPU / メモリ使用量
kubectl top nodes

# Node の使用率を計算（概算）
kubectl describe nodes | grep -A 10 "Allocated resources"

# 特定 Node の Conditions（MemoryPressure, DiskPressure 等）
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl describe node $NODE | grep -A 5 "Conditions:"
```

### 3. Pod のリソース使用量

```bash
# 全 Pod の使用量
kubectl top pods -n cka-monitor

# CPU でソート（クラスター全体）
kubectl top pods -A --sort-by=cpu | head -20

# メモリでソート
kubectl top pods -A --sort-by=memory | head -20

# コンテナ単位の使用量
kubectl top pods -n cka-monitor --containers

# cpu-burner が CPU を消費していることを確認
kubectl top pod cpu-burner -n cka-monitor
```

### 4. ログの確認

```bash
# Pod のログ（全体）
kubectl logs log-producer -n cka-monitor

# 末尾 N 行のみ表示
kubectl logs log-producer -n cka-monitor --tail=10

# リアルタイム追跡（Ctrl+C で停止）
kubectl logs log-producer -n cka-monitor -f

# 直近 30 秒のログのみ
kubectl logs log-producer -n cka-monitor --since=30s

# 直近 5 分のログのみ
kubectl logs log-producer -n cka-monitor --since=5m

# タイムスタンプ付きで表示
kubectl logs log-producer -n cka-monitor --timestamps

# 特定の時刻以降のログ
# kubectl logs log-producer -n cka-monitor --since-time='2026-03-07T00:00:00Z'

# Label セレクターで複数 Pod のログをまとめて表示
kubectl logs -l app=log-test -n cka-monitor --tail=5

# Deployment のすべての Pod のログ
kubectl logs deployment/log-test -n cka-monitor --tail=5

# 前回クラッシュしたコンテナのログ（CrashLoopBackOff の調査に重要）
# kubectl logs <pod-name> -n cka-monitor --previous
```

### 5. マルチコンテナ Pod のログ

```bash
# マルチコンテナ Pod を作成
cat <<EOF | kubectl apply -n cka-monitor -f -
apiVersion: v1
kind: Pod
metadata:
  name: multi-log
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "while true; do echo APP-LOG; sleep 3; done"]
  - name: sidecar
    image: busybox
    command: ["sh", "-c", "while true; do echo SIDECAR-LOG; sleep 3; done"]
EOF

# 特定コンテナのログ（-c でコンテナ名を指定）
kubectl logs multi-log -n cka-monitor -c app --tail=5
kubectl logs multi-log -n cka-monitor -c sidecar --tail=5

# 全コンテナのログ
kubectl logs multi-log -n cka-monitor --all-containers --tail=5
```

### 6. クラスターイベントの監視

```bash
# 全イベントを時系列で表示（最新が下）
kubectl get events -A --sort-by='.lastTimestamp' | tail -30

# Warning イベントのみ表示
kubectl get events -A --field-selector type=Warning

# 特定 Namespace のイベント
kubectl get events -n cka-monitor --sort-by='.lastTimestamp'

# 特定の Pod に関するイベント
kubectl get events -n cka-monitor --field-selector involvedObject.name=cpu-burner

# イベントをリアルタイム監視（新しいイベント発生時に表示。Ctrl+C で停止）
kubectl get events -n cka-monitor -w

# イベントの詳細をカスタム列で表示
kubectl get events -n cka-monitor -o custom-columns=\
'TIME:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message'
```

### 7. クラスター全体のヘルスチェック

```bash
# Node の状態
kubectl get nodes

# API Server のヘルス
kubectl get --raw /healthz
kubectl get --raw /readyz
kubectl get --raw /livez

# kube-system コンポーネントの状態
kubectl get pods -n kube-system

# CoreDNS のログ（DNS の問題調査）
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10

# kube-proxy のログ
kubectl logs -n kube-system -l component=kube-proxy --tail=10
```

### 8. リソース使用量でトラブルシューティング

```bash
# CPU を最も消費している Pod を探す
kubectl top pods -A --sort-by=cpu --no-headers | head -5

# メモリを最も消費している Pod を探す
kubectl top pods -A --sort-by=memory --no-headers | head -5

# 特定 Pod のリソース制限と実使用量を比較
kubectl get pod cpu-burner -n cka-monitor -o jsonpath='{.spec.containers[0].resources}' | python3 -m json.tool 2>/dev/null || kubectl get pod cpu-burner -n cka-monitor -o jsonpath='{.spec.containers[0].resources}'
kubectl top pod cpu-burner -n cka-monitor

# OOMKilled の Pod を検索
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}' | grep OOMKilled
```

### 🧹 クリーンアップ

```bash
# テスト用 Namespace を削除（全リソースが消える）
kubectl delete namespace cka-monitor

# 確認
kubectl get namespace | grep cka-monitor
```

---

## CKA 試験チェックリスト

- [ ] `kubectl top nodes/pods` でリソース使用量を確認できる
- [ ] `kubectl top pods --sort-by=cpu/memory` でソートできる
- [ ] `kubectl logs --tail/--since/--previous/-c/-f` を使いこなせる
- [ ] マルチコンテナ Pod で `-c` でコンテナ指定
- [ ] `kubectl get events --sort-by --field-selector` でイベント絞り込み
- [ ] OOMKilled の Pod を特定できる
