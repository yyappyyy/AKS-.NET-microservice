# Step 03: Kubernetes アーキテクチャ

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- Kubernetes クラスターの全体構成を説明できる
- Control Plane / Worker Node の各コンポーネントの役割を理解する
- kubectl の基本操作ができる
- AKS がマネージドで管理する部分を理解する

---

## クラスターの全体構成

```
┌───────────────────── AKS Cluster ──────────────────────┐
│                                                         │
│  ┌──── Control Plane (Azure がマネージド) ─────┐        │
│  │  kube-apiserver  │  etcd  │  scheduler     │        │
│  │  controller-manager  │  cloud-controller   │        │
│  └────────────────────────────────────────────┘        │
│                         │                               │
│         ┌───────────────┼───────────────┐              │
│         ▼               ▼               ▼              │
│  ┌── Node 1 ────┐ ┌── Node 2 ────┐ ┌── Node N ───┐   │
│  │ kubelet      │ │ kubelet      │ │ kubelet      │   │
│  │ kube-proxy   │ │ kube-proxy   │ │ kube-proxy   │   │
│  │ containerd   │ │ containerd   │ │ containerd   │   │
│  │ ┌───┐ ┌───┐ │ │ ┌───┐ ┌───┐ │ │ ┌───┐       │   │
│  │ │Pod│ │Pod│ │ │ │Pod│ │Pod│ │ │ │Pod│       │   │
│  │ └───┘ └───┘ │ │ └───┘ └───┘ │ │ └───┘       │   │
│  └─────────────┘ └─────────────┘ └─────────────┘   │
└─────────────────────────────────────────────────────┘
```

> **AKS のポイント:** Control Plane は Azure がマネージドで管理。
> Control Plane の料金は**無料**（Worker Node の VM 料金のみ）。

---

## Control Plane コンポーネント

| コンポーネント | 役割 | 覚え方 |
|---------------|------|--------|
| **kube-apiserver** | 全リクエストの入口。認証・認可・検証を行い REST API を提供 | 「受付窓口」 |
| **etcd** | クラスターの全データを保存する分散 KV ストア。**唯一のデータストア** | 「データベース」 |
| **kube-scheduler** | 新 Pod をどの Node に配置するか決定（フィルタリング→スコアリング→バインド） | 「席決め係」 |
| **kube-controller-manager** | Deployment, ReplicaSet 等のコントローラーを実行。望ましい状態を維持 | 「管理者」 |
| **cloud-controller-manager** | クラウド固有の制御 (Azure LB, Azure Disk 等) | 「Azure 連携」 |

### Pod 作成の流れ（重要！試験頻出）

```
kubectl apply -f pod.yaml
    │
    ▼
① kube-apiserver
   ├── 認証 (Authentication): 誰からのリクエストか？
   ├── 認可 (Authorization):  権限はあるか？（RBAC）
   ├── Admission Control:     ポリシーに違反していないか？
   └── etcd に保存
    │
    ▼
② etcd ──── 望ましい状態（Desired State）を永続化
    │
    ▼
③ kube-scheduler
   ├── フィルタリング: リソース不足の Node を除外
   ├── スコアリング:   残った Node にスコアを付ける
   └── バインド:       最高スコアの Node を選択
    │
    ▼
④ kubelet（選ばれた Node 上）
   ├── containerd にコンテナ起動を指示
   ├── Probe（readiness/liveness）を開始
   └── 状態を API Server に報告
```

---

## Worker Node コンポーネント

| コンポーネント | 役割 | 詳細 |
|---------------|------|------|
| **kubelet** | Pod のライフサイクル管理 | API Server の指示で containerd にコンテナ起動/停止を依頼。Probe も実行 |
| **kube-proxy** | ネットワークルール管理 | Service → Pod へのルーティングを iptables/IPVS で設定 |
| **Container Runtime** | コンテナ実行 | AKS では **containerd**（CNCF Graduated） |

### kubelet と kube-proxy の違い（試験に出る！）

```
kubelet（Pod のライフサイクル）:
  API Server ──「Pod を起動して」──▶ kubelet ──▶ containerd ──▶ コンテナ起動

kube-proxy（ネットワーク）:
  Pod A ──リクエスト──▶ Service IP ──kube-proxy のルール──▶ Pod B
```

---

## kubectl リファレンス

### リソースの確認

```bash
kubectl get <resource>                 # 一覧を簡易表示
kubectl get <resource> -o wide         # IP, Node名も表示
kubectl get <resource> -o yaml         # YAML 形式で全情報
kubectl get <resource> -o json         # JSON 形式
kubectl get <resource> --show-labels   # ラベルも表示
kubectl get <resource> -l app=my-app   # ラベルで絞り込み
kubectl get <resource> -w              # リアルタイム監視（Ctrl+C停止）
kubectl get <resource> --sort-by='.metadata.creationTimestamp'
kubectl get <resource> -A              # 全 Namespace
```

### 詳細表示

```bash
kubectl describe <resource> <name>
# → Events セクションにエラー原因が出る。トラブル時は最初に見る
```

### 作成・更新・削除

```bash
kubectl apply -f <file.yaml>       # 作成 or 更新（宣言的・推奨）
kubectl create -f <file.yaml>      # 作成のみ（既存ならエラー）
kubectl delete -f <file.yaml>      # ファイル定義のリソースを削除
kubectl delete <resource> <name>   # 名前指定で削除
```

### デバッグ

```bash
kubectl logs <pod>                 # ログ表示
kubectl logs <pod> -f              # リアルタイム追跡
kubectl logs <pod> --previous      # 前回クラッシュ時のログ
kubectl logs <pod> -c <container>  # マルチコンテナ Pod の特定コンテナ
kubectl exec -it <pod> -- sh       # コンテナ内にシェル接続
kubectl port-forward <pod> 8080:80 # ローカルから Pod にアクセス
kubectl top pod <pod>              # CPU/メモリ使用量
kubectl cp <pod>:/path ./local     # Pod からファイルコピー
```

### よく使う省略形

| 省略形 | 正式名 | 省略形 | 正式名 |
|--------|--------|--------|--------|
| `po` | pods | `svc` | services |
| `deploy` | deployments | `rs` | replicasets |
| `cm` | configmaps | `ns` | namespaces |
| `no` | nodes | `ep` | endpoints |
| `pvc` | persistentvolumeclaims | `hpa` | horizontalpodautoscalers |
| `ds` | daemonsets | `sts` | statefulsets |
| `sa` | serviceaccounts | `ing` | ingresses |

### Declarative vs Imperative

| 方式 | 例 | 特徴 | 使う場面 |
|------|-----|------|---------|
| **Imperative** | `kubectl run nginx --image=nginx` | 素早いが再現性低い | テスト、学習 |
| **Declarative** | `kubectl apply -f pod.yaml` | 再現性高い | **本番・GitOps（推奨）** |

> Kubernetes は **Declarative（宣言的）** が推奨。
> 「望ましい状態」を YAML で定義 → K8s が自動で合わせる = **Reconciliation Loop**

---

## AKS ハンズオン

### 1. クラスター接続の確認

```bash
# 接続先クラスターを確認
kubectl cluster-info

# kubeconfig のコンテキスト確認（複数クラスター切替時に重要）
kubectl config current-context

# 利用可能なコンテキスト一覧
kubectl config get-contexts

# AKS 接続情報を取得し直す場合
# az aks get-credentials --resource-group rg-aks-microservices --name aks-microservices
```

### 2. Node の確認

```bash
# Worker Node 一覧（AKS では Control Plane は Azure 管理のため非表示）
kubectl get nodes -o wide

# Node のラベル確認（スケジューリングに使われる）
kubectl get nodes --show-labels

# Node のリソース使用量
kubectl top nodes

# Node の詳細（OS, カーネル, Conditions, 空きリソース, 配置済み Pod）
kubectl describe node <node-name>
```

### 3. システムコンポーネントの確認

```bash
# kube-system の Pod（CoreDNS, kube-proxy, metrics-server 等）
kubectl get pods -n kube-system

# kube-system の全リソース
kubectl get all -n kube-system

# 全 Namespace 一覧
kubectl get namespaces

# CoreDNS のログ確認（DNS 問題の調査）
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10
```

### 4. API リソースの調査

```bash
# 利用可能な全リソースタイプ
kubectl api-resources | head -30

# リソースの仕様を調べる（マニフェスト作成の参考）
kubectl explain pod
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.ports
kubectl explain deployment.spec.strategy

# 全フィールドをツリー表示
kubectl explain pod.spec --recursive | head -50

# API バージョン一覧
kubectl api-versions
```

### 5. Imperative コマンドの練習

```bash
# Pod を即座に作成（学習・テスト用）
kubectl run test-nginx --image=nginx:1.27

# 確認
kubectl get pods test-nginx -o wide

# ログ確認
kubectl logs test-nginx

# Pod 内でコマンド実行
kubectl exec test-nginx -- hostname
kubectl exec test-nginx -- cat /etc/nginx/nginx.conf

# YAML を生成（実際には作成しない）
kubectl run sample --image=nginx --dry-run=client -o yaml

# Deployment を Imperative に作成
kubectl create deployment test-deploy --image=nginx --replicas=2

# 確認
kubectl get deploy,po

# 削除
kubectl delete pod test-nginx
kubectl delete deployment test-deploy
```

> **💡 テスト用リソースを作成した場合は上記の delete コマンドで削除してください。**

---

## KCNA 試験チェックリスト

- [ ] apiserver → etcd → scheduler → kubelet の処理フロー
- [ ] 各 Control Plane コンポーネントの役割を区別できる
- [ ] **etcd が唯一のデータストア** であること
- [ ] kubelet と kube-proxy の違い
- [ ] Declarative vs Imperative の違い
- [ ] Reconciliation Loop（調整ループ）の概念
- [ ] AKS が Control Plane をマネージドで管理すること
