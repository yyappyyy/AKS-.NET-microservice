# Step 05: ワークロードリソース

> **KCNA 配点: Kubernetes Fundamentals 46% + Container Orchestration 22%**

## 学習目標

- Deployment, ReplicaSet, DaemonSet, StatefulSet, Job の違いを理解する
- ローリングアップデートとロールバックを実行できる
- 各ワークロードの使い分けを説明できる

---

## リソースの階層関係

```
Deployment  ← 私たちが管理
  └── ReplicaSet  ← Deployment が自動管理
        └── Pod  ← ReplicaSet が指定数を維持
              └── Container
```

> **なぜ Pod を直接作らないのか？**
> Pod を直接作ると、クラッシュ時に自動復旧されない。
> Deployment を使えば ReplicaSet が自動で新しい Pod を作る（セルフヒーリング）。

---

## Deployment — 実プロジェクトの例

`k8s/product-catalog/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-catalog
  namespace: product-catalog
spec:
  replicas: 2                     # ← Pod を 2 つ維持
  selector:
    matchLabels:
      app: product-catalog        # ← この label の Pod を管理
  template:
    metadata:
      labels:
        app: product-catalog      # ← selector と一致（必須）
    spec:
      containers:
        - name: product-catalog
          image: yyaksmicroyy.azurecr.io/product-catalog:latest
```

### デプロイ戦略

| 戦略 | 動作 | ダウンタイム | 用途 |
|------|------|-------------|------|
| **RollingUpdate** (デフォルト) | 新旧を段階的に入れ替え | **なし** | 通常のアプリ |
| **Recreate** | 全停止 → 新起動 | **あり** | DB マイグレーション |

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1         # 更新中に +1 Pod 追加可能
    maxUnavailable: 1   # 更新中に 1 Pod まで停止可能
```

---

## ワークロードの使い分け

| ワークロード | 特徴 | 用途 | Pod 名 |
|-------------|------|------|--------|
| **Deployment** | レプリカ維持 + ローリングアップデート | Web API | `app-5f7b8c-x4j2k`（ランダム） |
| **DaemonSet** | **全 Node に 1 つずつ** | ログ収集、監視 | `agent-abc12` |
| **StatefulSet** | 安定した ID + 永続ストレージ | DB | `db-0`, `db-1`（連番） |
| **Job** | 1 回限りのタスク | データ移行 | `migrate-abc12` |
| **CronJob** | 定期実行の Job | バックアップ | `backup-xxx-abc12` |

---

## AKS ハンズオン

### 1. Deployment を作成する

```bash
# nginx-demo Deployment を作成（replicas: 3）
kubectl apply -f services/kcna-guide/step-05-workloads/deployment.yaml

# 階層を確認: Deployment → ReplicaSet → Pod
kubectl get deployment,replicaset,pods

# Deployment の詳細
kubectl describe deployment nginx-demo

# Deployment の YAML を確認
kubectl get deployment nginx-demo -o yaml
```

### 2. ローリングアップデート

```bash
# 現在のイメージを確認
kubectl get deployment nginx-demo -o jsonpath='{.spec.template.spec.containers[0].image}'
# 出力: nginx:1.27

# イメージを更新
kubectl set image deployment/nginx-demo nginx=nginx:1.28

# ロールアウト監視
kubectl rollout status deployment/nginx-demo

# ReplicaSet を確認（旧: DESIRED=0, 新: DESIRED=3）
kubectl get replicaset

# 全 Pod のイメージを確認
kubectl get pods -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image'
```

### 3. ロールバック

```bash
# ロールアウト履歴を確認
kubectl rollout history deployment/nginx-demo

# 特定リビジョンの詳細
kubectl rollout history deployment/nginx-demo --revision=1

# 直前のバージョンにロールバック
kubectl rollout undo deployment/nginx-demo

# 確認
kubectl rollout status deployment/nginx-demo

# 特定リビジョンに戻す場合
# kubectl rollout undo deployment/nginx-demo --to-revision=1
```

### 4. スケーリング

```bash
# Pod 数を 5 に変更
kubectl scale deployment/nginx-demo --replicas=5
kubectl get pods
# → 5 つの Pod

# 1 に縮小
kubectl scale deployment/nginx-demo --replicas=1
kubectl get pods
```

### 5. セルフヒーリングの確認

```bash
# 現在の Pod を確認
kubectl get pods

# Pod を 1 つ手動で削除
kubectl delete pod <pod-name>

# すぐに確認 → ReplicaSet が新しい Pod を自動作成
kubectl get pods
# → 新しい Pod が Creating/Running になっている！
```

### 6. Imperative で Deployment を作る

```bash
# コマンドで Deployment を作成
kubectl create deployment quick-test --image=nginx --replicas=2

# 確認
kubectl get deploy,po

# Deployment の YAML を生成（ファイル作成の雛形に）
kubectl create deployment sample --image=nginx --replicas=3 --dry-run=client -o yaml

# 削除
kubectl delete deployment quick-test
```

### 7. Job と CronJob を試す

```bash
# Job: 1 回限りのタスク
kubectl create job test-job --image=busybox -- echo "Hello from Job"

# Job の状態を確認（COMPLETIONS が 1/1 になれば完了）
kubectl get jobs
kubectl get pods  # Job が作成した Pod が Completed になる
kubectl logs job/test-job

# CronJob: 毎分実行
kubectl create cronjob test-cron --image=busybox --schedule="*/1 * * * *" -- echo "Hello every minute"

# CronJob の状態を確認
kubectl get cronjobs
# 1 分待つと Pod が作成される
kubectl get pods

# 削除
kubectl delete job test-job
kubectl delete cronjob test-cron
```

### 8. 実プロジェクトのデプロイ

```bash
kubectl apply -f k8s/base/
kubectl apply -f k8s/product-catalog/
kubectl get all -n product-catalog
kubectl rollout status deployment/product-catalog -n product-catalog
```

### 🧹 クリーンアップ

```bash
# 学習用リソースを削除
kubectl delete -f services/kcna-guide/step-05-workloads/deployment.yaml
kubectl delete job test-job --ignore-not-found
kubectl delete cronjob test-cron --ignore-not-found
kubectl delete deployment quick-test --ignore-not-found

# 実プロジェクトも削除する場合
# kubectl delete -f k8s/product-catalog/
# kubectl delete -f k8s/base/

# 確認
kubectl get deployment,replicaset,pods,jobs,cronjobs
```

---

## KCNA 試験チェックリスト

- [ ] Deployment → ReplicaSet → Pod の関係
- [ ] RollingUpdate（デフォルト）と Recreate の違い
- [ ] DaemonSet = 全 Node に 1 つ（ログ収集、監視）
- [ ] StatefulSet = 安定した Pod 名（`db-0`, `db-1`）+ 永続ストレージ
- [ ] Job = 1 回限り、CronJob = 定期実行
- [ ] `kubectl rollout undo` でロールバック
- [ ] Pod を直接作ると自動復旧されない（Deployment を使う理由）
