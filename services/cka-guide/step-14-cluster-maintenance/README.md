# Step 14: クラスターメンテナンス

> **CKA 配点: Cluster Architecture — 25%**

## 学習目標

- Node のメンテナンス手順（cordon → drain → 作業 → uncordon）
- クラスターのバージョンアップグレード
- リソースのバックアップとリストア

---

## AKS ハンズオン

### 1. 準備: テスト用リソースを作成

```bash
kubectl create namespace cka-maint

# Deployment を作成（drain の影響を確認するため）
kubectl create deployment maint-app --image=nginx --replicas=4 -n cka-maint

# 起動確認（Pod がどの Node に配置されているか確認）
kubectl get pods -n cka-maint -o wide
```

### 2. Node メンテナンス手順

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Target node: $NODE"

# ① cordon: Node をスケジュール不可にする（既存 Pod は残る）
kubectl cordon $NODE

# Node のステータスを確認（SchedulingDisabled になる）
kubectl get nodes

# 新しい Pod を作成してみる → cordon した Node には配置されない
kubectl run cordon-test --image=nginx -n cka-maint
kubectl get pod cordon-test -n cka-maint -o wide
# → $NODE 以外の Node に配置される

# ② drain: Node 上の Pod を安全に退避する
#   --ignore-daemonsets : DaemonSet の Pod は退避しない
#   --delete-emptydir-data : emptyDir のデータ削除を許可
#   --force : ReplicationController 等で管理されていない Pod も強制退避
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --force

# drain 後の Pod 分布を確認（$NODE の Pod は他の Node に移動）
kubectl get pods -n cka-maint -o wide
kubectl get pods -A --field-selector spec.nodeName=$NODE --no-headers

# ③ （ここでメンテナンス作業を実施）
echo "Maintenance in progress..."

# ④ uncordon: Node をスケジュール可能に戻す
kubectl uncordon $NODE

# Node のステータスを確認（Ready に戻る）
kubectl get nodes

# 新しい Pod は再び $NODE にも配置されるようになる
kubectl scale deployment maint-app -n cka-maint --replicas=6
kubectl get pods -n cka-maint -o wide
```

### 3. AKS クラスターバージョン管理

```bash
# 現在のバージョンを確認
kubectl version --short 2>/dev/null || kubectl version
az aks show --resource-group rg-aks-microservices --name aks-microservices \
  --query kubernetesVersion -o tsv

# 利用可能なアップグレードバージョン
az aks get-upgrades \
  --resource-group rg-aks-microservices \
  --name aks-microservices -o table

# Node Pool ごとのバージョン
az aks nodepool list \
  --resource-group rg-aks-microservices \
  --cluster-name aks-microservices \
  --query '[].{name:name,version:currentOrchestratorVersion,count:count,vmSize:vmSize}' -o table

# アップグレード実行（注意: 本番では事前テスト必須）
# az aks upgrade \
#   --resource-group rg-aks-microservices \
#   --name aks-microservices \
#   --kubernetes-version <target-version> \
#   --yes
```

### 4. kubeadm でのアップグレード手順（CKA 試験向け）

```bash
# ── Control Plane Node ──

# ① kubeadm をアップグレード
# apt update && apt install -y kubeadm=1.31.x-*

# ② アップグレードプランを確認
# kubeadm upgrade plan

# ③ アップグレードを実行
# kubeadm upgrade apply v1.31.x

# ④ kubelet と kubectl をアップグレード
# apt install -y kubelet=1.31.x-* kubectl=1.31.x-*

# ⑤ kubelet を再起動
# systemctl daemon-reload
# systemctl restart kubelet

# ── Worker Node（各 Node で実行）──

# ① Node を drain
# kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# ② kubeadm をアップグレード
# apt update && apt install -y kubeadm=1.31.x-*

# ③ Node のアップグレード
# kubeadm upgrade node

# ④ kubelet をアップグレード & 再起動
# apt install -y kubelet=1.31.x-*
# systemctl daemon-reload && systemctl restart kubelet

# ⑤ Node を uncordon
# kubectl uncordon <node>
```

### 5. リソースのバックアップ

```bash
# 特定 Namespace の全リソースを YAML エクスポート
kubectl get all -n cka-maint -o yaml > /tmp/cka-maint-backup.yaml

# ConfigMap と Secret もバックアップ
kubectl get configmap,secret -n cka-maint -o yaml >> /tmp/cka-maint-backup.yaml

# クラスター全体の主要リソースをバックアップ
kubectl get deployments -A -o yaml > /tmp/cluster-deployments.yaml
kubectl get services -A -o yaml > /tmp/cluster-services.yaml

# PV のバックアップ（クラスタースコープ）
kubectl get pv -o yaml > /tmp/cluster-pv.yaml

# バックアップファイルの確認
ls -la /tmp/cka-maint-backup.yaml /tmp/cluster-*.yaml 2>/dev/null
# PowerShell: Get-ChildItem /tmp/*backup*.yaml, /tmp/cluster-*.yaml
```

### 6. バックアップからリストア

```bash
# リソースを削除
kubectl delete deployment maint-app -n cka-maint

# 削除確認
kubectl get all -n cka-maint

# バックアップからリストア
kubectl apply -f /tmp/cka-maint-backup.yaml

# 復元確認
kubectl get all -n cka-maint
```

### 🧹 クリーンアップ

```bash
# ⚠️ uncordon を忘れずに！（drain した場合）
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl uncordon $NODE 2>/dev/null

# Node が Ready に戻ったことを確認
kubectl get nodes

# テスト用 Namespace を削除
kubectl delete namespace cka-maint

# バックアップファイルを削除
rm -f /tmp/cka-maint-backup.yaml /tmp/cluster-*.yaml 2>/dev/null
# PowerShell: Remove-Item /tmp/cka-maint-backup.yaml, /tmp/cluster-*.yaml -ErrorAction SilentlyContinue

# 確認
kubectl get namespaces | grep cka-maint
```

---

## CKA 試験チェックリスト

- [ ] cordon → drain → (作業) → uncordon の順序
- [ ] drain のオプション（`--ignore-daemonsets`, `--delete-emptydir-data`, `--force`）
- [ ] kubeadm upgrade plan → kubeadm upgrade apply
- [ ] Control Plane 先 → Worker Node 後の順でアップグレード
- [ ] `systemctl daemon-reload && systemctl restart kubelet`
- [ ] `kubectl get <resource> -o yaml` でバックアップ
