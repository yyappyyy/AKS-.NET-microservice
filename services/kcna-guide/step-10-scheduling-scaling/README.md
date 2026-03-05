# Step 10: スケジューリングとスケーリング

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- kube-scheduler のスケジューリングフローを理解する
- Taint / Toleration と Node Affinity を理解する
- HPA / VPA / Cluster Autoscaler の違いを理解する

---

## HPA — 実プロジェクトの例

`k8s/product-catalog/hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: product-catalog
  namespace: product-catalog
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: product-catalog
  minReplicas: 2                    # ← 最小 2 Pod
  maxReplicas: 10                   # ← 最大 10 Pod
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70    # ← CPU 70% 超でスケールアウト
```

## 3 種類のオートスケーラー

| スケーラー | 対象 | 説明 |
|-----------|------|------|
| **HPA** | Pod 数 | CPU/メモリに応じて Pod を増減 |
| **VPA** | Pod のリソース | requests/limits を自動調整 |
| **Cluster Autoscaler** | Node 数 | Pod が置けない時に Node 追加 |

> AKS では Cluster Autoscaler がネイティブ対応:
> `az aks update --enable-cluster-autoscaler --min-count 2 --max-count 5`

---

## Taint と Toleration

**Taint** = Node に「排除マーク」、**Toleration** = Pod が「許容宣言」

```bash
# GPU ノードに Taint を設定
kubectl taint nodes gpu-node workload=gpu:NoSchedule
```

| Effect | 動作 |
|--------|------|
| **NoSchedule** | Toleration のない Pod を配置しない |
| **PreferNoSchedule** | なるべく配置しない |
| **NoExecute** | 既存の Pod も退去させる |

---

## AKS ハンズオン

> **前提:** Product Catalog がデプロイ済みであること（Step 06 参照）

### 1. HPA の現在の状態を確認

```bash
# HPA の一覧を表示（TARGETS に現在のCPU使用率が見える）
kubectl get hpa -n product-catalog
#   TARGETS     MINPODS   MAXPODS   REPLICAS
#   <CPU>/70%   2         10        2

# HPA の詳細（スケールイベントの履歴等）
kubectl describe hpa product-catalog -n product-catalog
```

### 2. 負荷テストで HPA の動作を確認

```bash
# ターミナル 1: HPA をリアルタイム監視
kubectl get hpa -n product-catalog -w

# ターミナル 2: 負荷をかける（busybox で連続リクエスト）
#   --rm : 終了後に Pod を自動削除
#   -it  : 対話モード（Ctrl+C で停止）
kubectl run loadtest --image=busybox --rm -it -- sh -c \
  "while true; do wget -qO- http://product-catalog.product-catalog.svc/api/products; done"

# CPU 使用率が 70% を超えると Pod 数が自動で増える（数分かかる場合あり）
# 負荷を止めると数分後に Pod 数が減る
```

### 3. Node の Taint を確認（学習用）

```bash
# 現在の Node に設定されている Taint を確認
kubectl describe nodes | grep -A 3 Taints
```

### 🧹 クリーンアップ

```bash
# 負荷テスト Pod を停止: Ctrl+C（--rm オプションで自動削除される）

# HPA 監視を停止: Ctrl+C

# loadtest Pod が残っている場合は手動削除
kubectl delete pod loadtest --ignore-not-found

# Product Catalog を削除する場合（任意）
# kubectl delete -f k8s/product-catalog/
# kubectl delete -f k8s/base/
```

---

## KCNA 試験チェックリスト

- [ ] Scheduler: フィルタリング → スコアリング → バインド
- [ ] **Taint は Node、Toleration は Pod** に設定
- [ ] HPA (Pod数) vs VPA (リソース量) vs Cluster Autoscaler (Node数)
- [ ] Node Affinity の required vs preferred
