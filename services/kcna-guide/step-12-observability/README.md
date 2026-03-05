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

| 柱 | 何を見るか | ツール例 |
|----|-----------|---------|
| **Metrics** | CPU、レスポンス時間 | Prometheus (CNCF Graduated) |
| **Logs** | エラー、デバッグ情報 | Fluentd (CNCF Graduated) |
| **Traces** | サービス間の呼び出し | Jaeger (CNCF Graduated) |

## Prometheus（頻出！）

```
┌──────┐ Pull(scrape) ┌────────────┐  query  ┌─────────┐
│ App  │ ◀─────────── │ Prometheus │ ◀────── │ Grafana │
│/metrics│             │  (TSDB)    │         │ (表示)  │
└──────┘              └────────────┘         └─────────┘
```

- **Pull 型**: Prometheus がアプリの `/metrics` を定期的に取りに行く

### メトリクスタイプ

| タイプ | 説明 | 例 |
|--------|------|-----|
| **Counter** | 増加のみ | リクエスト数 |
| **Gauge** | 増減する | CPU 使用率 |
| **Histogram** | 分布 | レスポンス時間 |

## OpenTelemetry (CNCF Incubating)

メトリクス・ログ・トレースを**統一された仕様**で計装:
- ベンダーロックインを防ぐ
- 1 つの SDK で 3 本柱すべてに対応

---

## AKS ハンズオン

> **前提:** Product Catalog がデプロイ済みであること（Step 06 参照）

### 1. Node / Pod のリソース使用量を確認

```bash
# Node ごとの CPU / メモリ使用量を表示
#   metrics-server が必要（AKS ではデフォルトで有効）
kubectl top nodes

# Pod ごとの CPU / メモリ使用量
kubectl top pods -n product-catalog

# 全 Namespace の Pod 使用量
kubectl top pods --all-namespaces --sort-by=cpu
```

### 2. Pod のログを確認

```bash
# product-catalog の Pod ログを表示（直近 20 行）
#   -l : Label Selector（複数 Pod をまとめて取得）
kubectl logs -n product-catalog -l app=product-catalog --tail=20

# ログをリアルタイム追跡（Ctrl+C で停止）
kubectl logs -n product-catalog -l app=product-catalog -f

# 特定の Pod のログ
kubectl logs -n product-catalog <pod-name>

# 前回クラッシュしたコンテナのログ（トラブルシューティング用）
kubectl logs -n product-catalog <pod-name> --previous
```

### 3. AKS の Azure Monitor を有効化

```bash
# Azure Monitor（Container Insights）を有効化
#   → Azure Portal で CPU、メモリ、ログをグラフィカルに確認可能
az aks enable-addons \
  --resource-group rg-aks-microservices \
  --name aks-microservices \
  --addons monitoring

# 確認
az aks show --resource-group rg-aks-microservices --name aks-microservices \
  --query addonProfiles.omsagent.enabled
```

### 🧹 クリーンアップ

```bash
# Azure Monitor を無効化する場合（コスト削減）
az aks disable-addons \
  --resource-group rg-aks-microservices \
  --name aks-microservices \
  --addons monitoring

# ※ kubectl top / kubectl logs はリソースを作成しないのでクリーンアップ不要
```

---

## KCNA 試験チェックリスト

- [ ] 3 本柱: Metrics, Logs, Traces（**Alerts は含まない**）
- [ ] Prometheus = **Pull 型**
- [ ] Counter / Gauge / Histogram の違い
- [ ] OpenTelemetry = 統一的な計装（ベンダーロックイン防止）
- [ ] Fluentd / Fluent Bit = CNCF Graduated
