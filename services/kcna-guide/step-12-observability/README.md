# Step 12: Observability（可観測性）

> **KCNA 配点: Cloud Native Observability — 8%**

## 学習目標

- Observability の 3 本柱を理解する
- Prometheus / Grafana の役割を理解する
- OpenTelemetry の概念を理解する

---

## 3 本柱

```
             Observability
    ┌────────────┼────────────┐
    ▼            ▼            ▼
 Metrics       Logs        Traces
 数値の時系列   イベント記録   リクエスト追跡

 Prometheus    Fluentd      Jaeger
 Grafana       Fluent Bit   Zipkin
               Loki
```

| 柱 | 何を見るか | ツール例 | CNCF |
|----|-----------|---------|------|
| **Metrics** | CPU、応答時間、エラー率 | Prometheus | Graduated |
| **Logs** | エラーメッセージ、デバッグ | Fluentd, Fluent Bit | Graduated |
| **Traces** | サービス間の呼び出しフロー | Jaeger | Graduated |

> **Alerts は 3 本柱に含まれない。** Alerts は Observability を活用したアクション。

## Prometheus（頻出！）

```
┌──────┐ Pull(scrape) ┌────────────┐  query  ┌─────────┐
│ App  │ ◀─────────── │ Prometheus │ ◀────── │ Grafana │
│/metrics│             │  (TSDB)    │         │ (表示)  │
└──────┘              └────────────┘         └─────────┘
```

- **Pull 型**: Prometheus がアプリの `/metrics` を定期スクレイプ

### メトリクスタイプ

| タイプ | 動き | 例 |
|--------|------|-----|
| **Counter** | 増加のみ | リクエスト総数 |
| **Gauge** | 増減する | 現在の CPU 使用率 |
| **Histogram** | 分布を記録 | レスポンス時間の分布 |

## OpenTelemetry (CNCF Incubating)

3 本柱を**統一的な仕様と SDK**で計装:
- ベンダーロックインを防ぐ
- バックエンド（Prometheus, Jaeger 等）を自由に選択

---

## AKS ハンズオン

> **前提:** Product Catalog がデプロイ済み（Step 06 参照）

### 1. Node のリソース確認

```bash
# Node の CPU / メモリ使用量
kubectl top nodes

# Node の使用率を詳細に確認
kubectl describe nodes | grep -A 10 "Allocated resources"
```

### 2. Pod のリソース確認

```bash
# Pod の CPU / メモリ使用量
kubectl top pods -n product-catalog

# 全 Namespace の Pod を CPU 順でソート
kubectl top pods --all-namespaces --sort-by=cpu | head -20

# 全 Namespace の Pod をメモリ順でソート
kubectl top pods --all-namespaces --sort-by=memory | head -20

# 特定 Pod のリソース使用量
kubectl top pod -n product-catalog -l app=product-catalog
```

### 3. Pod のログ確認

```bash
# Pod ログ（直近 20 行）
kubectl logs -n product-catalog -l app=product-catalog --tail=20

# リアルタイム追跡（Ctrl+C で停止）
kubectl logs -n product-catalog -l app=product-catalog -f

# 特定 Pod のログ
POD=$(kubectl get pods -n product-catalog -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n product-catalog $POD

# タイムスタンプ付き
kubectl logs -n product-catalog $POD --timestamps

# 直近 5 分のログのみ
kubectl logs -n product-catalog $POD --since=5m

# 前回クラッシュしたコンテナのログ
kubectl logs -n product-catalog $POD --previous 2>/dev/null || echo "No previous logs"
```

### 4. Pod のイベントを確認

```bash
# Namespace 内の全イベントを時系列で表示
kubectl get events -n product-catalog --sort-by='.lastTimestamp'

# 警告イベントだけ表示
kubectl get events -n product-catalog --field-selector type=Warning

# クラスター全体のイベント
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### 5. Pod の状態を詳細に調査

```bash
# Pod の Conditions（True/False でヘルス状態がわかる）
kubectl get pods -n product-catalog -o custom-columns=\
'NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,PHASE:.status.phase'

# Pod の再起動回数
kubectl get pods -n product-catalog -o custom-columns=\
'NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount'
```

### 6. AKS の Azure Monitor を有効化

```bash
# Container Insights（Azure Monitor）を有効化
az aks enable-addons \
  --resource-group rg-aks-microservices \
  --name aks-microservices \
  --addons monitoring

# 有効化を確認
az aks show --resource-group rg-aks-microservices --name aks-microservices \
  --query addonProfiles.omsagent.enabled

# Azure Portal で確認:
#   AKS リソース → 監視 → インサイト → コンテナー
```

### 7. kube-system のログ確認（DNS 等のトラブル時）

```bash
# CoreDNS のログ
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20

# kube-proxy のログ
kubectl logs -n kube-system -l component=kube-proxy --tail=10

# metrics-server のログ
kubectl logs -n kube-system -l k8s-app=metrics-server --tail=10
```

### 🧹 クリーンアップ

```bash
# Azure Monitor を無効化する場合（コスト削減）
az aks disable-addons \
  --resource-group rg-aks-microservices \
  --name aks-microservices \
  --addons monitoring

# ※ kubectl top / logs / events はリソースを作成しないのでクリーンアップ不要
```

---

## KCNA 試験チェックリスト

- [ ] 3 本柱: Metrics, Logs, Traces（**Alerts は含まない**）
- [ ] Prometheus = **Pull 型**（スクレイプ）
- [ ] Counter（増加のみ）/ Gauge（増減）/ Histogram（分布）の違い
- [ ] OpenTelemetry = 統一的な計装（ベンダーロックイン防止）
- [ ] Fluentd / Fluent Bit = CNCF Graduated
- [ ] Grafana = メトリクスの可視化ダッシュボード
