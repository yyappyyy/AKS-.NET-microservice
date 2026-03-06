# Step 01: クラスターアーキテクチャ詳細

> **CKA 配点: Cluster Architecture, Installation & Configuration — 25%**

## 学習目標

- Control Plane / Worker Node の各コンポーネントの詳細な役割を理解する
- Static Pod と通常の Pod の違いを理解する
- クラスターの健全性を確認する方法を習得する
- kubeconfig の管理ができる

---

## Control Plane コンポーネント — 深掘り

### kube-apiserver

- 全リクエストの入口（唯一の通信ハブ）
- 認証 → 認可(RBAC) → Admission Control → etcd 書き込み
- 他のコンポーネントは全て apiserver を経由

### etcd

- 分散 KV ストア（Raft 合意アルゴリズム）
- クラスターの**唯一のデータストア**
- バックアップ・リストアは Step 04

### kube-scheduler

```
フィルタリング → スコアリング → バインド
   リソース要件       spread        選ばれた Node に
   Taint             affinity      Pod を割り当て
   nodeSelector      balance
```

### kube-controller-manager の主要コントローラー

| コントローラー | 役割 |
|---------------|------|
| ReplicaSet Controller | Pod レプリカ数を維持 |
| Deployment Controller | ローリングアップデート管理 |
| Node Controller | Node の状態監視（NotReady 検出） |
| Job Controller | Job 完了管理 |
| Endpoint Controller | Service と Pod の紐づけ |
| ServiceAccount Controller | SA の自動作成 |

---

## Static Pod

kubelet が直接管理する Pod（API Server を経由しない）:

- マニフェストは `/etc/kubernetes/manifests/` に配置
- kubeadm 環境では Control Plane コンポーネントが Static Pod
- AKS ではマネージドのため直接操作できないが概念理解は必須

---

## AKS ハンズオン

### 1. クラスターの健全性チェック

```bash
# クラスター情報（API Server の URL）
kubectl cluster-info

# kubectl と API Server のバージョン
kubectl version

# Node の STATUS を確認（Ready が正常）
kubectl get nodes

# Node の詳細情報（IP, OS, カーネル, containerd バージョン）
kubectl get nodes -o wide

# Node の Conditions をカスタム列で表示
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,STATUS:.status.conditions[-1].type,READY:.status.conditions[-1].status'

# Node のリソース使用量
kubectl top nodes

# Node の Allocatable リソース
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory,PODS:.status.allocatable.pods'

# Node の詳細（Conditions, Capacity, Allocated resources, Pod 一覧）
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl describe node $NODE

# Node の Taints を確認
kubectl describe nodes | grep -A 2 Taints

# Node のラベルを確認
kubectl get nodes --show-labels

# Node 上で動作している Pod の数を確認
kubectl get pods -A --field-selector spec.nodeName=$NODE --no-headers | wc -l
```

### 2. Control Plane コンポーネントの確認

```bash
# kube-system の Pod を確認
kubectl get pods -n kube-system -o wide

# Pod のステータスと再起動回数
kubectl get pods -n kube-system -o custom-columns=\
'NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName'

# CoreDNS の Deployment
kubectl get deployment coredns -n kube-system
kubectl describe deployment coredns -n kube-system | head -30

# kube-proxy の DaemonSet（全 Node に 1 つずつ動作）
kubectl get daemonset kube-proxy -n kube-system
kubectl get pods -n kube-system -l component=kube-proxy -o wide

# metrics-server の確認
kubectl get deployment metrics-server -n kube-system 2>/dev/null || echo "metrics-server not found as deployment"

# kube-system の全リソース
kubectl get all -n kube-system

# CoreDNS の ConfigMap（Corefile）
kubectl get configmap coredns -n kube-system -o yaml

# CoreDNS のログ
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10
```

### 3. API Server の情報

```bash
# API Server のヘルスチェック
kubectl get --raw /healthz
kubectl get --raw /readyz
kubectl get --raw /livez

# 利用可能な全リソースタイプ
kubectl api-resources --sort-by=name | head -30

# 特定 API グループのリソース
kubectl api-resources --api-group=apps
kubectl api-resources --api-group=networking.k8s.io
kubectl api-resources --api-group=rbac.authorization.k8s.io
kubectl api-resources --api-group=storage.k8s.io

# Namespace スコープのリソース数
kubectl api-resources --namespaced=true --no-headers | wc -l

# クラスタースコープのリソース数
kubectl api-resources --namespaced=false --no-headers | wc -l

# API バージョン一覧
kubectl api-versions

# 特定リソースの仕様を調べる
kubectl explain pod.spec.containers.resources
kubectl explain deployment.spec.strategy.rollingUpdate
kubectl explain service.spec.type
```

### 4. kubeconfig の管理

```bash
# 現在のコンテキスト
kubectl config current-context

# 全コンテキスト一覧
kubectl config get-contexts

# kubeconfig の内容（機密情報マスク）
kubectl config view --minify

# kubeconfig のフルパス
echo $KUBECONFIG
# デフォルト: ~/.kube/config

# デフォルト Namespace を変更（CKA 試験で毎問使う！）
kubectl config set-context --current --namespace=kube-system

# 確認
kubectl config view --minify | grep namespace

# default に戻す
kubectl config set-context --current --namespace=default

# AKS の credentials を再取得する場合
# az aks get-credentials --resource-group rg-aks-microservices --name aks-microservices --overwrite-existing
```

### 5. Namespace の管理

```bash
# 全 Namespace 一覧
kubectl get namespaces

# Namespace の詳細（ステータス、ラベル）
kubectl describe namespace default

# Namespace を作成
kubectl create namespace test-ns-01

# Namespace のラベルを追加
kubectl label namespace test-ns-01 env=test

# 確認
kubectl get namespace test-ns-01 --show-labels
```

### 6. Imperative でリソースを素早く作成

```bash
# Pod を即座に作成
kubectl run quick-nginx --image=nginx -n test-ns-01

# Deployment を即座に作成
kubectl create deployment quick-deploy --image=nginx --replicas=2 -n test-ns-01

# 確認
kubectl get pods,deploy -n test-ns-01

# YAML を生成（作成しない）— CKA 試験で雛形作りに必須
kubectl run sample --image=nginx --dry-run=client -o yaml
kubectl create deployment sample --image=nginx --replicas=3 --dry-run=client -o yaml
```

### 🧹 クリーンアップ

```bash
# 作成した Namespace を削除（中のリソースも一緒に消える）
kubectl delete namespace test-ns-01

# 確認
kubectl get namespaces | grep test-ns
# 何も表示されなければ OK

# デフォルト Namespace を default に戻す（変更していた場合）
kubectl config set-context --current --namespace=default
```

---

## CKA 試験チェックリスト

- [ ] Control Plane 各コンポーネントの詳細な役割
- [ ] Static Pod の概念（/etc/kubernetes/manifests/）
- [ ] kubeconfig のコンテキスト管理・Namespace 切替
- [ ] `kubectl cluster-info` / `kubectl get nodes` で健全性確認
- [ ] `kubectl api-resources` で Namespace スコープ vs クラスタースコープを区別
- [ ] `--dry-run=client -o yaml` で YAML 雛形を生成
