# Step 01: Cloud Native の基礎

> **KCNA 配点: Cloud Native Architecture — 16%**

## 学習目標

- Cloud Native の定義と原則を理解する
- CNCF (Cloud Native Computing Foundation) の役割を知る
- 12 Factor App の概念を理解する
- モノリスとマイクロサービスの違いを説明できる

---

## Cloud Native とは

CNCF の公式定義:

> クラウドネイティブ技術は、パブリッククラウド、プライベートクラウド、
> ハイブリッドクラウドなどのダイナミックな環境において、
> スケーラブルなアプリケーションを構築・実行するための技術です。

### Cloud Native の柱

```
┌──────────────────────────────────────────────┐
│             Cloud Native の柱                 │
├────────────┬────────────┬──────────┬──────────┤
│ コンテナ    │ マイクロ    │ CI/CD   │ DevOps   │
│            │ サービス    │         │          │
│ アプリの    │ 小さな独立  │ 自動化   │ 開発と    │
│ パッケージ  │ サービス群  │ デリバリ  │ 運用の融合 │
└────────────┴────────────┴──────────┴──────────┘
```

### このリポジトリとの対応

| 柱 | このリポジトリでの実現 |
|----|----------------------|
| コンテナ | `services/product-catalog/Dockerfile` でマルチステージビルド |
| マイクロサービス | `services/` 配下に独立サービスを配置 |
| CI/CD | GitHub Actions (`.github/workflows/`) |
| DevOps | `scripts/` でインフラ構築を自動化 |

---

## CNCF (Cloud Native Computing Foundation)

- Linux Foundation 配下のプロジェクト
- Kubernetes、Prometheus 等をホスト
- **CNCF Landscape**: クラウドネイティブのツール全体図

### プロジェクトの成熟度（試験に頻出！）

| レベル | 意味 | 主な例 |
|--------|------|--------|
| **Graduated** | 本番利用可能 | Kubernetes, Prometheus, Envoy, containerd, Helm, ArgoCD, Flux, Fluentd |
| **Incubating** | 成長中 | OpenTelemetry, Kyverno, gRPC, Knative |
| **Sandbox** | 初期段階 | 多数 |

---

## 12 Factor App

| # | Factor | 説明 | このプロジェクトでの例 |
|---|--------|------|----------------------|
| 1 | Codebase | 1つのコードベース | モノレポ構成 |
| 2 | Dependencies | 依存関係を明示 | `.csproj` の PackageReference |
| 3 | **Config** | 設定を環境変数に | `ConfigMap` (`k8s/product-catalog/configmap.yaml`) |
| 4 | Backing services | 外部リソース化 | 将来のDB接続 |
| 5 | Build, release, run | 分離 | Dockerfile のマルチステージ |
| 6 | **Processes** | ステートレス | `ConcurrentDictionary`（インメモリ） |
| 7 | Port binding | ポートで公開 | `EXPOSE 8080`, Service |
| 8 | Concurrency | プロセスでスケール | HPA (`k8s/product-catalog/hpa.yaml`) |
| 9 | Disposability | 高速起動/停止 | .NET Minimal API の高速起動 |
| 10 | Dev/prod parity | 環境の一致 | Docker で同一イメージ |
| 11 | **Logs** | ストリーム化 | `stdout` 出力 → K8s が収集 |
| 12 | Admin processes | 一回限りのプロセス | Job / CronJob |

---

## モノリス vs マイクロサービス

```
モノリス                        マイクロサービス（このリポジトリ）
┌──────────────────┐           ┌─────────┐ ┌─────────┐ ┌─────────┐
│  UI              │           │Product  │ │ Order   │ │ User    │
│  ビジネスロジック  │    →      │Catalog  │ │ Mgmt    │ │ Service │
│  データアクセス    │           │ API+DB  │ │ API+DB  │ │ API+DB  │
│  DB              │           └─────────┘ └─────────┘ └─────────┘
└──────────────────┘           独立デプロイ、独立スケール
```

| 比較項目 | モノリス | マイクロサービス |
|----------|----------|-----------------|
| デプロイ | 全体を一括 | サービス単位で独立 |
| スケール | 全体をスケール | 必要なサービスだけ（HPAで自動） |
| 技術選択 | 統一 | サービスごとに可能 |
| 障害影響 | 全体に波及 | 障害サービスのみ |
| 複雑さ | シンプル | ネットワーク、分散トランザクション |

---

## KCNA 試験チェックリスト

- [ ] CNCF の役割と Graduated プロジェクト（Kubernetes, Prometheus, containerd, Helm, ArgoCD, Flux）
- [ ] Cloud Native の定義を 1 文で説明できる
- [ ] 12 Factor App の主要原則（特に Config, Processes, Logs）
- [ ] マイクロサービスのメリット・デメリット
- [ ] サーバーレス / FaaS（Azure Functions 等）の概念
