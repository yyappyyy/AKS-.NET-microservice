# Step 05: ワークロードリソース

> **KCNA 配点: Kubernetes Fundamentals 46% + Container Orchestration 22%**

## 学習目標

- Deployment, ReplicaSet, DaemonSet, StatefulSet, Job の違いを理解する
- ローリングアップデートとロールバックを実行できる
- 各ワークロードの使い分けを説明できる

---

## リソースの階層関係

```
Deployment  ← 私たちが管理する
  └── ReplicaSet  ← Deployment が自動管理
        └── Pod  ← ReplicaSet が維持
              └── Container
```

## Deployment — 実プロジェクトの例

`k8s/product-catalog/deployment.yaml` のポイント:

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
        app: product-catalog      # ← selector と一致させる
    spec:
      containers:
        - name: product-catalog
          image: yyaksmicroyy.azurecr.io/product-catalog:latest
```

### デプロイ戦略

| 戦略 | 動作 | 用途 |
|------|------|------|
| **RollingUpdate** (デフォルト) | 新旧を段階的に入れ替え | ダウンタイムなし |
| **Recreate** | 全 Pod 停止 → 新 Pod 起動 | DB マイグレーション時 |

---

## ワークロードの使い分け

| ワークロード | 特徴 | 用途例 |
|-------------|------|--------|
| **Deployment** | レプリカ数維持、ローリングアップデート | Web API（Product Catalog） |
| **ReplicaSet** | Pod のレプリカ維持（Deployment が管理） | 直接使用しない |
| **DaemonSet** | **全 Node に 1 つずつ** Pod を配置 | ログ収集(Fluentd)、監視 |
| **StatefulSet** | 安定した ID + 永続ストレージ | DB (MySQL, PostgreSQL) |
| **Job** | 1 回限りのタスク | データ移行 |
| **CronJob** | 定期実行 | バックアップ |

---

## AKS ハンズオン

### 1. Deployment を作成する

```bash
# nginx-demo Deployment を作成（replicas: 3）
kubectl apply -f services/kcna-guide/step-05-workloads/deployment.yaml

# Deployment → ReplicaSet → Pod の階層を確認
#   Deployment が ReplicaSet を作り、ReplicaSet が Pod を作る
kubectl get deployment,replicaset,pods

# Deployment の詳細（戦略、レプリカ数、イベント等）
kubectl describe deployment nginx-demo
```

### 2. ローリングアップデートを試す

```bash
# イメージを nginx:1.27 → nginx:1.28 に更新
#   RollingUpdate 戦略で段階的に Pod が入れ替わる
kubectl set image deployment/nginx-demo nginx=nginx:1.28

# ロールアウトの進行状況をリアルタイムで監視
#   全 Pod が更新されると "successfully rolled out" と表示
kubectl rollout status deployment/nginx-demo

# 更新後の ReplicaSet を確認
#   → 旧 ReplicaSet (DESIRED=0) と新 ReplicaSet (DESIRED=3) が見える
kubectl get replicaset
```

### 3. ロールバック（前のバージョンに戻す）

```bash
# ロールアウト履歴を確認
kubectl rollout history deployment/nginx-demo

# 直前のバージョンにロールバック
kubectl rollout undo deployment/nginx-demo

# 特定のリビジョンに戻す場合
# kubectl rollout undo deployment/nginx-demo --to-revision=1
```

### 4. スケーリング

```bash
# Pod 数を手動で 5 に変更
kubectl scale deployment/nginx-demo --replicas=5

# 確認（5 つの Pod が Running になる）
kubectl get pods
```

### 5. 実プロジェクト（Product Catalog）のデプロイ

```bash
# Namespace を作成してからサービスをデプロイ
kubectl apply -f k8s/base/
kubectl apply -f k8s/product-catalog/

# 全リソースを確認
kubectl get all -n product-catalog
```

### 🧹 クリーンアップ

```bash
# 学習用 Deployment を削除（Pod も ReplicaSet も自動削除される）
kubectl delete -f services/kcna-guide/step-05-workloads/deployment.yaml
# 出力: deployment.apps "nginx-demo" deleted

# 実プロジェクトも削除する場合（任意）
kubectl delete -f k8s/product-catalog/
kubectl delete -f k8s/base/

# 削除確認
kubectl get deployment,replicaset,pods
```

---

## KCNA 試験チェックリスト

- [ ] Deployment → ReplicaSet → Pod の関係
- [ ] RollingUpdate（デフォルト）と Recreate の違い
- [ ] DaemonSet = 全 Node に 1 つ、StatefulSet = 安定した ID
- [ ] Job = 1 回限り、CronJob = 定期実行
- [ ] `kubectl rollout undo` でロールバック
