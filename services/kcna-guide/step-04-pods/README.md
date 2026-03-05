# Step 04: Pod の基礎

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- Pod が Kubernetes の最小デプロイ単位であることを理解する
- Pod のマニフェストを読み書きできる
- マルチコンテナパターン (Sidecar, Init Container) を理解する
- Probe（ヘルスチェック）の種類と用途を理解する
- Pod のライフサイクルを理解する

---

## Pod とは

Kubernetes の**最小デプロイ単位**。1 つ以上のコンテナをグループ化する。

```
┌──────────────── Pod ─────────────────┐
│  IP: 10.244.0.15                      │
│  ┌──────────┐    ┌──────────┐        │
│  │Container │    │Container │        │
│  │  (app)   │    │ (sidecar)│        │
│  └──────────┘    └──────────┘        │
│       │               │              │
│       └── localhost ───┘  ← 共有      │
│  Shared Volume: /data     ← 共有     │
└───────────────────────────────────────┘
```

**同一 Pod 内のコンテナが共有するもの:**
- ネットワーク（同じ IP、localhost で通信可能）
- ストレージ（Volume）
- ライフサイクル（一緒に起動・停止）

**Pod は 1 つの Node 上でのみ動作する**（複数 Node にまたがれない）。

---

## Pod のライフサイクル

```
Pending → Running → Succeeded / Failed
```

| Phase | 説明 | よくある原因（トラブル時） |
|-------|------|-------------------------|
| **Pending** | Node への配置待ち、イメージ Pull 中 | リソース不足、イメージ名ミス |
| **Running** | 少なくとも 1 つのコンテナが実行中 | — |
| **Succeeded** | 全コンテナが正常終了（Job 等） | — |
| **Failed** | コンテナが異常終了 | アプリのクラッシュ |
| **CrashLoopBackOff** | クラッシュ→再起動を繰り返し | 設定ミス、ポート競合 |
| **ImagePullBackOff** | イメージ取得に失敗 | イメージ名ミス、認証エラー |

---

## Probe（ヘルスチェック）— 実プロジェクトの例

`k8s/product-catalog/deployment.yaml` で使われている Probe:

```yaml
livenessProbe:            # コンテナが生きているか？
  httpGet:
    path: /healthz        # ← Program.cs の app.MapHealthChecks("/healthz")
    port: 8080
  initialDelaySeconds: 10 # 起動後 10 秒待ってから開始
  periodSeconds: 15       # 15 秒ごとにチェック
  timeoutSeconds: 5       # 5 秒以内に応答がないとタイムアウト
  failureThreshold: 3     # 3 回連続失敗で再起動

readinessProbe:           # トラフィックを受けられるか？
  httpGet:
    path: /readyz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3
```

| Probe | 失敗時の動作 | 用途 | 覚え方 |
|-------|-------------|------|--------|
| **livenessProbe** | **コンテナを再起動** | デッドロック検出 | 「生きてる？」→ 死んでたら再起動 |
| **readinessProbe** | **Service から除外** | 準備完了チェック | 「準備OK？」→ まだならトラフィック止める |
| **startupProbe** | 他の Probe を無効化 | 起動が遅いアプリ | 「起動した？」→ 完了するまで待つ |

### Probe の方式

| 方式 | 説明 | 例 |
|------|------|-----|
| **httpGet** | HTTP GET でパスにアクセス | `/healthz` に 200 が返るか |
| **tcpSocket** | TCP ソケット接続 | ポート 3306 に接続できるか |
| **exec** | コンテナ内でコマンド実行 | `cat /tmp/healthy` の終了コードが 0 か |

---

## リソース制限 — 実プロジェクトの例

```yaml
resources:
  requests:          # ← スケジューリング時の最低保証量
    memory: "128Mi"  #    scheduler がこの量のメモリがある Node を選ぶ
    cpu: "100m"      #    100 millicore = 0.1 CPU コア
  limits:            # ← 超えてはいけない上限値
    memory: "256Mi"  #    超過 → OOMKill（コンテナ強制終了）
    cpu: "250m"      #    超過 → スロットリング（CPU を絞られる）
```

| リソース | 単位 | 例 |
|----------|------|-----|
| CPU | millicore (m) | `100m` = 0.1 core, `1000m` = 1 core |
| Memory | MiB, GiB | `128Mi` = 128 MiB, `1Gi` = 1 GiB |

---

## マルチコンテナパターン

### Sidecar パターン

メインコンテナを**補助する**コンテナを同居:

```
Pod: ┌──────────┐  ┌──────────┐
     │ App      │  │ Log      │ ← Sidecar
     │ (main)   │──│ Collector│
     └──────────┘  └──────────┘
           └── 共有 Volume ──┘
```
用途: ログ収集、プロキシ、セキュリティエージェント

### Init Container

メインの**前に**実行される初期化コンテナ:

```yaml
spec:
  initContainers:
    - name: wait-for-db
      image: busybox
      command: ["sh", "-c", "until nslookup db-service; do sleep 2; done"]
  containers:
    - name: app
      image: my-app:latest
```
用途: DB 準備待ち、設定ダウンロード、マイグレーション

---

## AKS ハンズオン

### 1. Pod を作成する

```bash
# pod-basic.yaml で Pod を作成
kubectl apply -f services/kcna-guide/step-04-pods/pod-basic.yaml

# Pod が Running になるまで監視（Ctrl+C で終了）
kubectl get pods -w
```

### 2. Pod の状態を確認する

```bash
# 一覧表示（IP, Node名 付き）
kubectl get pods -o wide

# YAML で全情報を確認
kubectl get pod my-nginx -o yaml

# ラベルを確認
kubectl get pod my-nginx --show-labels

# 詳細（Conditions, Probe 状態, Events）
kubectl describe pod my-nginx

# 特定のフィールドだけ取得（jsonpath）
kubectl get pod my-nginx -o jsonpath='{.status.phase}'
# 出力: Running

kubectl get pod my-nginx -o jsonpath='{.status.podIP}'
# 出力: 10.244.x.x
```

### 3. Pod のログを確認する

```bash
# ログ全体を表示
kubectl logs my-nginx

# 末尾 20 行だけ
kubectl logs my-nginx --tail=20

# リアルタイム追跡（Ctrl+C で停止）
kubectl logs my-nginx -f

# タイムスタンプ付き
kubectl logs my-nginx --timestamps

# 直近 5 分のログだけ
kubectl logs my-nginx --since=5m
```

### 4. Pod の中に入る（デバッグ）

```bash
# シェルで接続
kubectl exec -it my-nginx -- sh

# Pod 内で実行するコマンド例:
#   hostname              → Pod 名が返る
#   cat /etc/os-release   → コンテナの OS
#   curl localhost:80      → Probe と同じチェック
#   env                   → 環境変数
#   df -h                 → ディスク使用量
#   ps aux                → プロセス一覧
#   exit                  → シェルから抜ける

# シェルに入らずコマンドを直接実行
kubectl exec my-nginx -- hostname
kubectl exec my-nginx -- cat /etc/nginx/nginx.conf
kubectl exec my-nginx -- ls -la /usr/share/nginx/html/
kubectl exec my-nginx -- env | head -10
```

### 5. Pod のリソース・ネットワーク確認

```bash
# CPU / メモリの使用量
kubectl top pod my-nginx

# Pod の IP を取得
kubectl get pod my-nginx -o jsonpath='{.status.podIP}'

# Pod が配置された Node を確認
kubectl get pod my-nginx -o jsonpath='{.spec.nodeName}'
```

### 6. Imperative で Pod を作る

```bash
# YAML なしで Pod を作成（テスト用）
kubectl run test-busybox --image=busybox --command -- sleep 3600

# 確認
kubectl get pods test-busybox

# YAML を生成（実際には作成しない）— マニフェストの雛形作りに便利
kubectl run sample-pod --image=nginx --dry-run=client -o yaml

# Pod に環境変数付きで作成
kubectl run test-env --image=busybox \
  --env="MY_VAR=hello" --command -- sh -c "echo $MY_VAR && sleep 3600"
```

### 7. トラブルシューティング手順

```bash
# ① STATUS を確認
kubectl get pods

# ② Events を確認（原因のヒント）
kubectl describe pod my-nginx

# ③ ログを確認（アプリのエラー）
kubectl logs my-nginx

# ④ 前回クラッシュ時のログ（CrashLoopBackOff の場合）
kubectl logs my-nginx --previous

# ⑤ Pod 内でデバッグ
kubectl exec -it my-nginx -- sh
```

### 🧹 クリーンアップ

```bash
# 作成した全 Pod を削除
kubectl delete -f services/kcna-guide/step-04-pods/pod-basic.yaml
kubectl delete pod test-busybox test-env --ignore-not-found

# 確認
kubectl get pods
```

---

## KCNA 試験チェックリスト

- [ ] Pod が最小デプロイ単位であること
- [ ] 同一 Pod 内のコンテナはネットワーク・ストレージを共有
- [ ] Pod は 1 つの Node 上でのみ動作する
- [ ] liveness / readiness / startup Probe の違いと失敗時の動作
- [ ] httpGet / tcpSocket / exec の 3 つの Probe 方式
- [ ] requests（保証）と limits（上限）の違い
- [ ] Sidecar パターン: メインと補助コンテナが同居
- [ ] Init Container: メインの前に実行される初期化コンテナ
- [ ] Pod のライフサイクル（Pending → Running → Succeeded/Failed）
