# Step 15: 模擬問題と総復習

## 試験直前サマリー

| ドメイン | 配点 | 最低限覚えること |
|----------|------|-----------------|
| K8s Fundamentals | **46%** | コンポーネント、Pod、Service、Deployment、ConfigMap、RBAC |
| Container Orchestration | **22%** | コンテナ vs VM、OCI、ワークロード、スケジューリング |
| Cloud Native Architecture | **16%** | CNCF、12 Factor、マイクロサービス、GitOps |
| Observability | **8%** | 3 本柱、Prometheus(Pull型)、OpenTelemetry |
| App Delivery | **8%** | Helm(Tiller不要)、ArgoCD/Flux(Pull型) |

---

## 模擬問題 30 問（全問に丁寧な解説付き）

---

### Q1. etcd の役割

クラスターの全データを保存する分散キーバリューストアはどれですか？

- A) kube-apiserver
- B) kube-scheduler
- C) **etcd** ✅
- D) kube-controller-manager

**解説:**
etcd は Kubernetes クラスターの**唯一のデータストア**です。
Pod、Service、ConfigMap など全てのリソース情報がここに保存されます。
kube-apiserver は API の入口、scheduler は Pod の配置先決定、
controller-manager はコントローラーの実行を担当します。
覚え方:「**e**verything is **t**here in et**cd**」

---

### Q2. containerd

CNCF Graduated で、AKS が使用する高レベルコンテナランタイムはどれですか？

- A) runc
- B) **containerd** ✅
- C) CRI-O
- D) Docker Engine

**解説:**
**containerd** は CNCF Graduated の高レベルコンテナランタイムです。
Docker Engine の内部で使われており、AKS でもデフォルトのランタイムです。
- **runc** は低レベルランタイム（OCI Runtime Spec の参照実装）
- **CRI-O** は CNCF Incubating で、Kubernetes 専用の軽量ランタイム
- **Docker Engine** 自体はランタイムではなく、containerd を内包するツール

---

### Q3. Pod の特徴

Pod について正しい説明はどれですか？

- A) 1 つの Pod には 1 つのコンテナのみ
- B) Pod 内の各コンテナは異なる IP を持つ
- C) **Pod 内のコンテナは同じネットワーク名前空間を共有する** ✅
- D) Pod は複数の Node にまたがれる

**解説:**
Pod 内のコンテナは**同じ IP アドレスを共有**し、`localhost` で互いに通信できます。
- A) Pod は複数コンテナを含められる（Sidecar パターン等）
- B) 逆。同じ IP を共有する
- D) Pod は必ず 1 つの Node 上で動作する

---

### Q4. readinessProbe

コンテナがトラフィックを受ける準備ができているか確認する Probe はどれですか？

- A) livenessProbe
- B) **readinessProbe** ✅
- C) startupProbe
- D) healthProbe

**解説:**
- **readinessProbe** → 失敗すると **Service から除外**（トラフィックが来なくなる）
- **livenessProbe** → 失敗すると **コンテナを再起動**
- **startupProbe** → 起動完了まで他の Probe を無効化
- healthProbe は Kubernetes には存在しない

Product Catalog では `/readyz` を readinessProbe、`/healthz` を livenessProbe に使っています。

---

### Q5. ClusterIP

クラスター内部でのみアクセス可能な Service タイプはどれですか？

- A) NodePort
- B) LoadBalancer
- C) **ClusterIP** ✅
- D) ExternalName

**解説:**
**ClusterIP** はデフォルトの Service タイプで、クラスター内部からのみアクセス可能です。
Product Catalog の Service もこのタイプです。
外部公開には NodePort（開発向け）や LoadBalancer（本番 AKS）を使います。
ExternalName は外部 DNS 名への CNAME エイリアスです。

---

### Q6. RollingUpdate

Deployment のデフォルトのデプロイ戦略はどれですか？

- A) Recreate
- B) BlueGreen
- C) Canary
- D) **RollingUpdate** ✅

**解説:**
**RollingUpdate** がデフォルトで、古い Pod を徐々に新しい Pod に置き換えます。
`maxSurge`（追加できる Pod 数）と `maxUnavailable`（停止できる Pod 数）で速度を制御。
- **Recreate** は全 Pod を一旦停止してから新 Pod を起動（ダウンタイムあり）
- BlueGreen / Canary は K8s ネイティブの戦略ではない（Argo Rollouts 等で実装）

---

### Q7. Secret のエンコーディング

Secret のデータのエンコーディング方式はどれですか？

- A) AES-256 暗号化
- B) SHA-256 ハッシュ
- C) **base64 エンコード** ✅
- D) RSA 暗号化

**解説:**
Secret のデータは **base64 エンコード**されているだけで、**暗号化ではありません**。
`echo "YWRtaW4=" | base64 -d` で簡単にデコードできます。
本番では AKS の Azure Key Vault + CSI Driver を使います。
これは KCNA でよく出る「ひっかけ問題」です。

---

### Q8. kube-system

kube-system Namespace に含まれるのはどれですか？

- A) ユーザーアプリケーション
- B) **Kubernetes システムコンポーネント** ✅
- C) テスト用リソース
- D) 外部サービス

**解説:**
**kube-system** には CoreDNS、kube-proxy、metrics-server などの
システムコンポーネントが配置されます。
ユーザーアプリは専用 Namespace（`product-catalog` 等）に配置します。

---

### Q9. Role vs ClusterRole

Namespace スコープの権限を定義するリソースはどれですか？

- A) ClusterRole
- B) **Role** ✅
- C) ClusterRoleBinding
- D) ServiceAccount

**解説:**
- **Role** = **特定の Namespace 内**の権限を定義
- **ClusterRole** = **クラスター全体**の権限を定義
- RoleBinding / ClusterRoleBinding は Role をユーザーに紐づける
- ServiceAccount は Pod の ID であり、権限定義そのものではない

---

### Q10. ReadWriteOnce

PV で単一 Node からの読み書きを示す Access Mode はどれですか？

- A) **ReadWriteOnce (RWO)** ✅
- B) ReadOnlyMany (ROX)
- C) ReadWriteMany (RWX)
- D) ReadWriteOncePod (RWOP)

**解説:**
- **RWO**: 1 つの Node から読み書き（Azure Disk はこれのみ対応）
- **ROX**: 複数 Node から読み取りのみ
- **RWX**: 複数 Node から読み書き（Azure Files で対応）
- **RWOP**: 1 つの Pod のみ（比較的新しい概念）

---

### Q11. DaemonSet

DaemonSet の特徴として正しいのはどれですか？

- A) 指定数のレプリカ維持
- B) **全 Node に 1 つずつ Pod を配置** ✅
- C) 順序付きの Pod 名を提供
- D) 1 回限りのタスクを実行

**解説:**
- **DaemonSet**: 全 Node に 1 つずつ。用途: ログ収集(Fluentd)、監視エージェント
- A) は ReplicaSet / Deployment
- C) は StatefulSet（`db-0`, `db-1`, `db-2`）
- D) は Job

---

### Q12. Taint の目的

Node に Taint を設定する目的はどれですか？

- A) Pod を引き寄せる
- B) **特定の Pod だけがスケジュールされるようにする** ✅
- C) Node のラベルを変更する
- D) Node のリソース制限

**解説:**
**Taint は Node に「排除マーク」**を付ける仕組みです。
Toleration を宣言した Pod だけがその Node にスケジュールされます。
- Pod を引き寄せるのは **Node Affinity**
覚え方: **「Taint は Node に、Toleration は Pod に」**

---

### Q13. HPA のデフォルトメトリクス

HPA がデフォルトで監視するメトリクスはどれですか？

- A) ディスク使用量
- B) ネットワークトラフィック
- C) **CPU 使用率** ✅
- D) メモリリーク率

**解説:**
HPA は **CPU 使用率** をデフォルトで監視します。
Product Catalog では `averageUtilization: 70`（70%超でスケールアウト）に設定。
メモリやカスタムメトリクスも追加可能ですがデフォルトは CPU です。

---

### Q14. Helm v3 と Tiller

Helm v3 で不要になったコンポーネントはどれですか？

- A) Chart
- B) Release
- C) Repository
- D) **Tiller** ✅

**解説:**
Helm v2 では **Tiller** というサーバーがクラスター内に必要でした。
Tiller はクラスター管理者権限を持ちセキュリティリスクがありました。
**Helm v3 で Tiller を完全廃止**し、RBAC ベースで動作します。
KCNA 頻出問題です。

---

### Q15. values.yaml

Helm Chart のデフォルト設定値ファイルはどれですか？

- A) Chart.yaml
- B) **values.yaml** ✅
- C) templates/deployment.yaml
- D) requirements.yaml

**解説:**
- **Chart.yaml**: メタ情報（名前、バージョン）
- **values.yaml**: デフォルトのカスタマイズパラメータ
- **templates/**: K8s マニフェストのテンプレート
- requirements.yaml: Helm v2 の依存管理（v3 では Chart.yaml に統合）

---

### Q16. GitOps の Source of Truth

GitOps の「Single Source of Truth」はどれですか？

- A) Kubernetes Cluster
- B) Docker Registry
- C) **Git Repository** ✅
- D) Helm Repository

**解説:**
GitOps では **Git リポジトリが Single Source of Truth** です。
クラスターの望ましい状態は全て Git で管理し、
ArgoCD / Flux がその状態をクラスターに自動的に反映します。
このリポジトリでは `k8s/` ディレクトリが K8s マニフェストの Source of Truth です。

---

### Q17. ArgoCD のデプロイ方式

ArgoCD のデプロイ方式はどれですか？

- A) Push 型
- B) **Pull 型** ✅
- C) ハイブリッド型
- D) バッチ型

**解説:**
ArgoCD は **Pull 型**: クラスター内のエージェントが Git リポジトリを監視し、
差分を検出して自動的にクラスターに適用します。
Push 型（GitHub Actions → `kubectl apply`）とは異なり、
CI にクラスター認証情報を持たせる必要がありません。

---

### Q18. Prometheus の収集方式

Prometheus のメトリクス収集方式はどれですか？

- A) Push 型
- B) **Pull 型（スクレイプ）** ✅
- C) ストリーミング型
- D) バッチ型

**解説:**
Prometheus は **Pull 型** で、アプリの `/metrics` エンドポイントを
定期的にスクレイプ（取得）します。
Push 型ツール: Datadog Agent、StatsD。
KCNA ではこの「Pull 型」がよく問われます。

---

### Q19. Observability の 3 本柱

Observability の 3 本柱に**含まれない**のはどれですか？

- A) Metrics
- B) Logs
- C) Traces
- D) **Alerts** ✅

**解説:**
3 本柱は **Metrics、Logs、Traces** です。
Alerts はObservability を活用した**アクション**であり、柱ではありません。

---

### Q20. OpenTelemetry

OpenTelemetry の主な目的はどれですか？

- A) ログの永続化
- B) **メトリクス・ログ・トレースの統一的な収集** ✅
- C) アラートの管理
- D) ダッシュボードの作成

**解説:**
**OpenTelemetry** (CNCF Incubating) は 3 本柱を**統一された仕様と SDK**で計装。
ベンダーロックインを防ぎ、バックエンド（Prometheus, Jaeger 等）を自由に選択できます。

---

### Q21. CNCF Graduated

CNCF Graduated プロジェクトはどれですか？

- A) Knative
- B) **Kubernetes** ✅
- C) OpenTelemetry
- D) Backstage

**解説:**
**Kubernetes** は CNCF 最初の Graduated プロジェクトです。
他の Graduated: Prometheus, containerd, Envoy, Helm, ArgoCD, Flux, Fluentd
- Knative, OpenTelemetry, Backstage は全て **Incubating**

---

### Q22. 12 Factor の Config

設定を環境変数に格納する原則はどれですか？

- A) Codebase
- B) Dependencies
- C) **Config** ✅
- D) Processes

**解説:**
12 Factor App の **#3 Config** =「設定は環境変数に」。
Kubernetes では **ConfigMap** でこの原則を実現します。
Product Catalog では `ASPNETCORE_ENVIRONMENT` を ConfigMap で管理。

---

### Q23. NetworkPolicy のデフォルト

Kubernetes のデフォルトのネットワークポリシーはどれですか？

- A) 全通信を拒否
- B) **全通信を許可** ✅
- C) 同一 Namespace のみ許可
- D) Ingress のみ許可

**解説:**
NetworkPolicy を何も設定しない場合、**全ての Pod 間通信が許可**されます。
ゼロトラストを実現するには「デフォルト拒否 + 必要な通信のみ許可」にします。

---

### Q24. runAsNonRoot

コンテナを root 以外で実行を強制する設定はどれですか？

- A) readOnlyRootFilesystem
- B) **runAsNonRoot** ✅
- C) allowPrivilegeEscalation
- D) capabilities

**解説:**
Product Catalog の deployment.yaml でも `runAsNonRoot: true` を設定しています。
- **readOnlyRootFilesystem**: ルート FS を読み取り専用に
- **allowPrivilegeEscalation**: 特権昇格の防止
- **capabilities**: Linux ケーパビリティの制御

---

### Q25. Ingress Controller

Ingress が動作するために必要なコンポーネントはどれですか？

- A) kube-proxy
- B) CoreDNS
- C) **Ingress Controller** ✅
- D) metrics-server

**解説:**
**Ingress リソースだけでは動作しません。**
Ingress Controller（NGINX, Traefik 等）が別途必要です。
AKS では Helm で NGINX Ingress Controller をインストールできます。

---

### Q26. StatefulSet

StatefulSet が提供する機能はどれですか？

- A) 全 Node への Pod 配置
- B) **安定したネットワーク ID と永続ストレージ** ✅
- C) 定期バッチ実行
- D) 自動スケーリング

**解説:**
StatefulSet は Pod に**安定した名前**（`db-0`, `db-1`）と
**永続ストレージ**（VolumeClaimTemplate）を提供。
- A) は DaemonSet、C) は CronJob、D) は HPA

---

### Q27. コンテナが軽量な理由

コンテナが VM より軽量な主な理由はどれですか？

- A) ハイパーバイザーを使用する
- B) **ホスト OS のカーネルを共有する** ✅
- C) 専用ハードウェアを使用する
- D) ネットワークスタックが不要

**解説:**
コンテナは**ホスト OS のカーネルを共有**するため、
OS 全体をエミュレートする VM と比べて軽量（MB vs GB）で高速起動（秒 vs 分）。
ハイパーバイザーは VM の技術です。

---

### Q28. kube-scheduler

kube-scheduler の役割はどれですか？

- A) etcd のデータ管理
- B) コンテナイメージのビルド
- C) **新しい Pod をどの Node に配置するか決定** ✅
- D) Service のロードバランシング

**解説:**
kube-scheduler は「フィルタリング → スコアリング → バインド」で Node を選択。
- etcd 管理は apiserver の役割
- イメージビルドは Docker/CI の役割
- ロードバランシングは kube-proxy / Service の役割

---

### Q29. requests と limits

Pod の requests について正しいのはどれですか？

- A) requests は上限値
- B) **requests はスケジューリングに使われる最低保証量** ✅
- C) limits を超えても Pod は動作し続ける
- D) requests と limits は同じ値でなければならない

**解説:**
- **requests**: スケジューリング時の**保証量**。この分のリソースがある Node に配置
- **limits**: 超えられない**上限**。CPU 超過→スロットリング、メモリ超過→OOMKill

Product Catalog: requests(128Mi, 100m) / limits(256Mi, 250m)

---

### Q30. OCI の仕様

OCI が策定する仕様に**含まれない**のはどれですか？

- A) Runtime Spec
- B) Image Spec
- C) Distribution Spec
- D) **Orchestration Spec** ✅

**解説:**
OCI は以下の **3 つの仕様のみ**を策定:
1. **Runtime Spec** — コンテナの実行方法
2. **Image Spec** — イメージのフォーマット
3. **Distribution Spec** — イメージの配布方法

**Orchestration は OCI の範囲外** — それは Kubernetes の役割です。

---

## 採点と次のステップ

| 正答数 | 得点率 | 判定 |
|--------|--------|------|
| **23+/30** | 75%+ | ✅ 合格ライン到達！ |
| 18-22/30 | 60-73% | ⚠️ 弱点を復習 |
| 17以下 | 56%以下 | ❌ Step 01 から再学習 |

### 間違えた問題 → 復習先

| 問題 | 復習 Step |
|------|----------|
| Q1, 3, 28 | [Step 03](../step-03-k8s-architecture/) アーキテクチャ |
| Q3, 4, 29 | [Step 04](../step-04-pods/) Pod の基礎 |
| Q6, 11, 26 | [Step 05](../step-05-workloads/) ワークロード |
| Q5, 25 | [Step 06](../step-06-services-networking/) Service |
| Q7, 22 | [Step 07](../step-07-config-secrets/) ConfigMap/Secret |
| Q10 | [Step 08](../step-08-storage/) ストレージ |
| Q8, 9 | [Step 09](../step-09-namespace-rbac/) Namespace/RBAC |
| Q12, 13 | [Step 10](../step-10-scheduling-scaling/) スケジューリング |
| Q14, 15 | [Step 11](../step-11-helm/) Helm |
| Q18, 19, 20 | [Step 12](../step-12-observability/) Observability |
| Q16, 17 | [Step 13](../step-13-gitops-cicd/) GitOps |
| Q23, 24, 30 | [Step 14](../step-14-security/) セキュリティ |
| Q2, 27 | [Step 02](../step-02-container-basics/) コンテナ |
| Q21 | [Step 01](../step-01-cloud-native-basics/) Cloud Native |

### 本番試験へ

1. このリポジトリの Product Catalog を AKS にデプロイして手を動かす
2. [KCNA 公式](https://training.linuxfoundation.org/certification/kubernetes-cloud-native-associate/) で最新情報を確認
3. 試験申込（$250、オンライン受験可能）
