# Step 04: Pod の基礎

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- Pod が Kubernetes の最小デプロイ単位であることを理解する
- Pod のマニフェストを読み書きできる
- マルチコンテナパターン (Sidecar, Init Container) を理解する
- Probe（ヘルスチェック）の種類と用途を理解する

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
- ライフサイクル

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
  failureThreshold: 3     # 3 回失敗で再起動

readinessProbe:           # トラフィックを受けられるか？
  httpGet:
    path: /readyz         # ← Program.cs の app.MapHealthChecks("/readyz")
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3
```

| Probe | 失敗時の動作 | 用途 |
|-------|-------------|------|
| **livenessProbe** | **コンテナを再起動** | デッドロック検出 |
| **readinessProbe** | **Service から除外**（再起動しない） | 準備完了チェック |
| **startupProbe** | 他の Probe を無効化 | 起動が遅いアプリ |

---

## リソース制限 — 実プロジェクトの例

```yaml
resources:
  requests:          # ← スケジューリング時の最低保証
    memory: "128Mi"  #    「少なくとも128MiBのメモリがあるNodeに配置して」
    cpu: "100m"      #    「0.1 CPU コア」
  limits:            # ← 超えてはいけない上限
    memory: "256Mi"  #    超過 → OOMKill (強制終了)
    cpu: "250m"      #    超過 → スロットリング (速度制限)
```

---

## マルチコンテナパターン

### Sidecar パターン
メインコンテナを補助するコンテナを同居:
- ログ収集、プロキシ、モニタリング

### Init Container
メインの**前に**実行される初期化コンテナ:
- DB の準備待ち、設定ファイルのダウンロード

---

## AKS ハンズオン

### 1. Pod を作成する

```bash
# リポジトリのルートから実行
# pod-basic.yaml を使って Pod を作成（宣言的アプローチ）
kubectl apply -f services/kcna-guide/step-04-pods/pod-basic.yaml
# 出力: pod/my-nginx created
```

### 2. Pod の状態を確認する

```bash
# Pod の一覧を表示（STATUS が Running になるまで待つ）
#   -o wide : Node 名や IP アドレスも表示
kubectl get pods -o wide

# Pod の詳細情報を表示（イベント、Probe の状態、IP 等）
#   問題がある時はここの Events セクションを確認する
kubectl describe pod my-nginx

# Pod のログを表示（コンテナの stdout/stderr）
kubectl logs my-nginx

# ログをリアルタイムで追跡する場合（Ctrl+C で停止）
kubectl logs my-nginx -f
```

### 3. Pod の中に入る（デバッグ）

```bash
# Pod 内のコンテナにシェルで接続
#   -it : 対話モード（interactive + tty）
#   -- sh : 実行するコマンド
kubectl exec -it my-nginx -- sh

# Pod 内で実行できるコマンド例:
#   curl localhost:80          # Probe と同じチェック
#   cat /etc/nginx/nginx.conf  # 設定ファイル確認
#   exit                       # シェルから抜ける
```

### 4. Pod のリソース使用量を確認

```bash
# CPU / メモリの使用量を確認（metrics-server が必要）
kubectl top pod my-nginx
```

### 🧹 クリーンアップ

```bash
# 作成した Pod を削除
kubectl delete -f services/kcna-guide/step-04-pods/pod-basic.yaml
# 出力: pod "my-nginx" deleted

# 削除されたことを確認
kubectl get pods
# my-nginx が表示されなければ OK
```

---

## KCNA 試験チェックリスト

- [ ] Pod が最小デプロイ単位
- [ ] 同一 Pod 内のコンテナはネットワーク・ストレージを共有
- [ ] liveness / readiness / startup Probe の違い
- [ ] requests（保証）と limits（上限）の違い
- [ ] Sidecar パターンと Init Container の違い
