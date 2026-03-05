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

> **AKS のポイント:** Control Plane は Azure がマネージドで管理するため、
> ユーザーは Worker Node の管理とアプリのデプロイに集中できます。

---

## Control Plane コンポーネント

| コンポーネント | 役割 | 覚え方 |
|---------------|------|--------|
| **kube-apiserver** | 全リクエストの入口。REST API 提供 | 「受付窓口」 |
| **etcd** | クラスターの全データを保存する KV ストア | 「データベース」 |
| **kube-scheduler** | 新 Pod をどの Node に置くか決定 | 「席決め係」 |
| **kube-controller-manager** | Deployment 等のコントローラーを実行 | 「管理者」 |
| **cloud-controller-manager** | クラウド固有の制御 (LB, ディスク) | 「Azure 連携」 |

### Pod 作成の流れ（重要！）

```
kubectl apply
    │
    ▼
① kube-apiserver ──── リクエスト受信、認証・認可・検証
    │
    ▼
② etcd ──────────── 望ましい状態を保存
    │
    ▼
③ kube-scheduler ── 最適な Node を選択
    │
    ▼
④ kubelet ────────── Node 上で containerd を呼び出し Pod を起動
```

---

## Worker Node コンポーネント

| コンポーネント | 役割 |
|---------------|------|
| **kubelet** | Node 上の Pod のライフサイクル管理 |
| **kube-proxy** | Service の通信ルールを管理（iptables / IPVS） |
| **Container Runtime** | コンテナ実行 (AKS では containerd) |

---

## kubectl 基本操作

```bash
kubectl get <resource>             # 一覧
kubectl describe <resource> <name> # 詳細
kubectl apply -f <file.yaml>       # 作成/更新（宣言的）
kubectl delete -f <file.yaml>      # 削除
kubectl logs <pod>                 # ログ
kubectl exec -it <pod> -- sh       # コンテナに入る
kubectl get pods -o wide           # 追加情報付き
kubectl get pods -o yaml           # YAML出力
```

### Declarative vs Imperative

| 方式 | 例 | 特徴 |
|------|-----|------|
| **Imperative** | `kubectl run nginx --image=nginx` | 素早いが再現性低い |
| **Declarative** | `kubectl apply -f pod.yaml` | 再現性高い。**GitOps 向き** |

---

## AKS ハンズオン

### クラスター情報の確認

```bash
# 現在接続しているクラスターを確認
#   → 正しい AKS クラスターに接続されているか最初に確認する
kubectl cluster-info

# Worker Node の一覧を表示（-o wide で IP や OS 情報も表示）
#   AKS では Control Plane は Azure が管理するため Worker Node のみ表示される
kubectl get nodes -o wide

# Node の詳細情報（OS, カーネル, コンテナランタイム等）
kubectl describe node <node-name>
```

### システムコンポーネントの確認

```bash
# kube-system Namespace の Pod を確認
#   → CoreDNS, kube-proxy, metrics-server 等のシステムコンポーネント
kubectl get pods -n kube-system

# kube-system の全リソースを表示
kubectl get all -n kube-system
```

### API リソースの調査

```bash
# Kubernetes で使える全リソースタイプを一覧表示
kubectl api-resources | head -20

# 特定リソースの仕様を調べる（マニフェスト作成時に参照）
kubectl explain pod                      # Pod の概要
kubectl explain pod.spec.containers      # containers フィールドの詳細
kubectl explain deployment.spec.strategy # デプロイ戦略の詳細
```

> **💡 このステップではリソースを作成しないため、クリーンアップは不要です。**

---

## KCNA 試験チェックリスト

- [ ] apiserver → etcd → scheduler → kubelet の処理フロー
- [ ] 各 Control Plane コンポーネントの役割を区別できる
- [ ] **etcd が唯一のデータストア** であること
- [ ] kubelet と kube-proxy の違い
- [ ] Declarative vs Imperative の違い
- [ ] AKS が Control Plane をマネージドで管理すること
