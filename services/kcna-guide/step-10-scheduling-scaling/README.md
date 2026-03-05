# Step 10: スケジューリングとスケーリング

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- kube-scheduler のスケジューリングフローを理解する
- Taint / Toleration と Node Affinity を理解する
- HPA / VPA / Cluster Autoscaler の違いを理解する

---

## スケジューリングの流れ

```
Pod 作成要求
    │
    ▼
kube-scheduler
    ├── ① フィルタリング: 条件を満たさない Node を除外
    │   （リソース不足、Taint、NodeSelector 不一致...）
    ├── ② スコアリング: 残った Node にスコアを付ける
    │   （リソースバランス、Affinity 一致度...）
    └── ③ バインド: 最高スコアの Node に配置
```

---

## NodeSelector

最もシンプルな配置制御:

```yaml
spec:
  nodeSelector:
    disktype: ssd      # disktype=ssd ラベルの Node にのみ配置
```

---

## Taint と Toleration

**Taint** = Node に「排除マーク」、**Toleration** = Pod が「許容宣言」

```
Node (Taint: workload=gpu:NoSchedule)
  ├── Pod A (Toleration なし)  → ❌ 配置不可
  └── Pod B (Toleration あり)  → ✅ 配置可能
```

| Effect | 動作 |
|--------|------|
| **NoSchedule** | Toleration なしの新 Pod を配置しない |
| **PreferNoSchedule** | なるべく配置しない（強制ではない） |
| **NoExecute** | 既存の Pod も**退去**させる |

> 覚え方: **「Taint は Node、Toleration は Pod」**

---

## Node Affinity

| 種類 | 説明 |
|------|------|
| `requiredDuringScheduling...` | **必須条件**（不一致なら配置しない） |
| `preferredDuringScheduling...` | **優先条件**（不一致でも配置する） |

---

## HPA — 実プロジェクトの例

`k8s/product-catalog/hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: product-catalog
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: product-catalog
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70    # ← 70% 超でスケールアウト
```

### 3 種類のオートスケーラー（試験頻出！）

| スケーラー | 何をスケール | 説明 |
|-----------|-------------|------|
| **HPA** | **Pod 数**（水平） | CPU/メモリに応じて Pod を増減 |
| **VPA** | **Pod のリソース**（垂直） | requests/limits を自動調整 |
| **Cluster Autoscaler** | **Node 数** | Pod が置けない時に Node 追加 |

```
負荷増加 → HPA: Pod増 → Node空きなし → Cluster Autoscaler: Node追加
負荷減少 → HPA: Pod減 → Nodeガラガラ → Cluster Autoscaler: Node削除
```

---

## AKS ハンズオン

> **前提:** Product Catalog がデプロイ済み（Step 06 参照）

### 1. HPA の確認

```bash
# HPA 一覧（TARGETS に現在 CPU 使用率）
kubectl get hpa -n product-catalog

# HPA の詳細（スケールイベント履歴）
kubectl describe hpa product-catalog -n product-catalog

# 現在の Pod 数
kubectl get pods -n product-catalog
```

### 2. 手動スケーリング

```bash
# Pod 数を 4 に変更
kubectl scale deployment product-catalog -n product-catalog --replicas=4
kubectl get pods -n product-catalog

# 元に戻す
kubectl scale deployment product-catalog -n product-catalog --replicas=2
```

### 3. 負荷テストで HPA 自動スケールを確認

```bash
# ターミナル 1: HPA をリアルタイム監視
kubectl get hpa -n product-catalog -w

# ターミナル 2: 負荷をかける
kubectl run loadtest --image=busybox --rm -it -- sh -c \
  "while true; do wget -qO- http://product-catalog.product-catalog.svc/api/products; done"

# CPU 70% 超で Pod 数が増える（2〜3 分かかる）
# 負荷停止（Ctrl+C）後、数分で Pod 数が減る
```

### 4. Node の情報を確認

```bash
# Node のリソース使用量
kubectl top nodes

# Node のラベル
kubectl get nodes --show-labels

# Node の Taint を確認
kubectl describe nodes | grep -A 3 Taints

# Node の Conditions（Ready, MemoryPressure 等）
kubectl describe nodes | grep -A 5 Conditions

# Node の空きリソース
kubectl describe nodes | grep -A 5 Allocatable
```

### 5. Taint の操作（学習用）

```bash
# Node 名を取得
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Taint を追加（test 用なので影響は少ない effect で）
kubectl taint nodes $NODE_NAME test-taint=learning:PreferNoSchedule

# Taint を確認
kubectl describe node $NODE_NAME | grep Taints

# Taint を削除（末尾に - を付ける）
kubectl taint nodes $NODE_NAME test-taint=learning:PreferNoSchedule-
```

### 6. Node にラベルを付ける

```bash
# ラベルを追加
kubectl label nodes $NODE_NAME disktype=ssd

# 確認
kubectl get nodes --show-labels | grep disktype

# ラベルを削除（末尾に - を付ける）
kubectl label nodes $NODE_NAME disktype-
```

### 7. AKS Cluster Autoscaler

```bash
# Cluster Autoscaler を有効化（AKS）
# az aks update --resource-group rg-aks-microservices --name aks-microservices \
#   --enable-cluster-autoscaler --min-count 2 --max-count 5

# Cluster Autoscaler の状態確認
# kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml
```

### 🧹 クリーンアップ

```bash
# 負荷テスト停止: Ctrl+C（--rm で自動削除）
# HPA 監視停止: Ctrl+C

# loadtest Pod が残っている場合
kubectl delete pod loadtest --ignore-not-found

# Taint やラベルを追加した場合は上記の削除コマンドで元に戻す
```

---

## KCNA 試験チェックリスト

- [ ] Scheduler: フィルタリング → スコアリング → バインド
- [ ] **Taint は Node、Toleration は Pod** に設定
- [ ] NoSchedule / PreferNoSchedule / NoExecute の違い
- [ ] Node Affinity: required vs preferred
- [ ] **HPA**(Pod数) vs **VPA**(リソース量) vs **Cluster Autoscaler**(Node数)
- [ ] HPA のデフォルトメトリクスは **CPU 使用率**
