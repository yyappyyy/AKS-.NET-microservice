# Step 02: kubeadm とクラスター構築

> **CKA 配点: Cluster Architecture, Installation & Configuration — 25%**

## 学習目標

- kubeadm によるクラスター構築手順を理解する
- AKS でのクラスター作成・管理を実践する
- クラスターのアップグレード手順を理解する

---

## kubeadm によるクラスター構築（概念）

> CKA では kubeadm の操作が出題される。AKS はマネージドだが概念理解は必須。

### 構築フロー

```
① kubeadm init（Control Plane）
   ├── CA 証明書の生成
   ├── Static Pod 作成（apiserver, etcd, scheduler, controller-manager）
   ├── kubeconfig 生成
   └── join トークン発行

② kubeadm join（Worker Node）
   ├── Control Plane に接続
   ├── kubelet, kube-proxy 設定
   └── Node としてクラスターに参加
```

### 主要コマンド（CKA 試験で覚える）

```bash
# Control Plane 初期化
# kubeadm init --pod-network-cidr=10.244.0.0/16

# Worker Node の参加
# kubeadm join <control-plane>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# join トークンの再生成
# kubeadm token create --print-join-command

# 設定の確認
# kubeadm config print init-defaults
```

---

## AKS ハンズオン

### 1. AKS クラスター情報の確認

```bash
# クラスターの詳細情報
az aks show --resource-group rg-aks-microservices --name aks-microservices \
  --query '{name:name,version:kubernetesVersion,state:provisioningState,location:location}' -o table

# Kubernetes バージョン
kubectl version

# Node 数と VM サイズ
az aks nodepool list \
  --resource-group rg-aks-microservices \
  --cluster-name aks-microservices \
  --query '[].{name:name,count:count,vmSize:vmSize,version:currentOrchestratorVersion,mode:mode}' -o table

# Node の確認
kubectl get nodes -o wide
```

### 2. Node Pool の操作

```bash
# Node Pool 一覧
az aks nodepool list \
  --resource-group rg-aks-microservices \
  --cluster-name aks-microservices -o table

# Node Pool のスケール（Node 数を変更）
# az aks nodepool scale \
#   --resource-group rg-aks-microservices \
#   --cluster-name aks-microservices \
#   --name nodepool1 \
#   --node-count 3

# 新しい Node Pool の追加
# az aks nodepool add \
#   --resource-group rg-aks-microservices \
#   --cluster-name aks-microservices \
#   --name pool2 \
#   --node-count 1 \
#   --node-vm-size Standard_B2s \
#   --labels workload=batch

# Node Pool の削除
# az aks nodepool delete \
#   --resource-group rg-aks-microservices \
#   --cluster-name aks-microservices \
#   --name pool2
```

### 3. クラスターのアップグレード確認

```bash
# 現在のバージョン
az aks show --resource-group rg-aks-microservices --name aks-microservices \
  --query kubernetesVersion -o tsv

# 利用可能なアップグレードバージョン
az aks get-upgrades \
  --resource-group rg-aks-microservices \
  --name aks-microservices -o table

# アップグレード実行（コメントアウト — 本番では事前テスト必須）
# az aks upgrade \
#   --resource-group rg-aks-microservices \
#   --name aks-microservices \
#   --kubernetes-version <target-version> \
#   --yes
```

### 4. kubeconfig の管理（AKS）

```bash
# AKS の kubeconfig を取得
# az aks get-credentials \
#   --resource-group rg-aks-microservices \
#   --name aks-microservices \
#   --overwrite-existing

# 現在のコンテキスト
kubectl config current-context

# コンテキスト一覧
kubectl config get-contexts

# kubeconfig の内容
kubectl config view --minify
```

### 5. kubectl を使ったクラスター調査

```bash
# クラスター情報
kubectl cluster-info

# API Server のヘルス
kubectl get --raw /healthz

# 全 Namespace の Pod 数
kubectl get pods -A --no-headers | wc -l

# kube-system の Pod
kubectl get pods -n kube-system -o wide

# Node のラベル
kubectl get nodes --show-labels

# Node の詳細
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') | head -50
```

### 6. Namespace を使った環境分離の練習

```bash
# 複数の Namespace を作成（マイクロサービスの環境分離）
kubectl create namespace dev-env
kubectl create namespace staging-env
kubectl create namespace prod-env

# 各 Namespace にラベルを付ける
kubectl label namespace dev-env env=development
kubectl label namespace staging-env env=staging
kubectl label namespace prod-env env=production

# 確認
kubectl get namespaces --show-labels | grep -E "dev|staging|prod"

# 各環境にテスト用 Deployment を作成
kubectl create deployment web --image=nginx --replicas=1 -n dev-env
kubectl create deployment web --image=nginx --replicas=2 -n staging-env
kubectl create deployment web --image=nginx --replicas=3 -n prod-env

# 各環境の Pod 数を確認
kubectl get pods -n dev-env
kubectl get pods -n staging-env
kubectl get pods -n prod-env
```

### 🧹 クリーンアップ

```bash
# テスト用 Namespace を削除（中のリソースも全て消える）
kubectl delete namespace dev-env staging-env prod-env

# 確認
kubectl get namespaces | grep -E "dev|staging|prod"
# 何も表示されなければ OK
```

---

## CKA 試験チェックリスト

- [ ] `kubeadm init` / `kubeadm join` の流れを理解
- [ ] `kubeadm token create --print-join-command` を知っている
- [ ] クラスターアップグレード手順（drain → upgrade → uncordon）
- [ ] `kubeadm upgrade plan` / `kubeadm upgrade apply`
- [ ] AKS と kubeadm の違い（マネージド vs セルフマネージド）
- [ ] kubeconfig の管理（コンテキスト切替、credentials 取得）
