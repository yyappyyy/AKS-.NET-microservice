# Step 11: Node のトラブルシューティング

> **CKA 配点: Troubleshooting — 30%（最大配点！）**

## 学習目標

- Node が NotReady になる原因を特定し、修復できる
- kubelet のステータスを確認・再起動できる
- Node の cordon / drain / uncordon を実行できる

---

## Node トラブルシューティング手順

```
① kubectl get nodes          → STATUS を確認
② kubectl describe node      → Conditions / Events を確認
③ ssh to node                → kubelet のログを確認
④ systemctl status kubelet   → kubelet の状態
⑤ journalctl -u kubelet      → kubelet のエラーログ
```

---

## AKS ハンズオン

### 1. Node の状態チェック

```bash
# Node の STATUS を確認（Ready / NotReady）
kubectl get nodes

# Node の Conditions を詳細に確認
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# 主要な Conditions:
#   Ready: True           → 正常
#   MemoryPressure: False → メモリ余裕あり
#   DiskPressure: False   → ディスク余裕あり
#   PIDPressure: False    → プロセス数余裕あり

# Conditions を一覧で確認
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,MEM:.status.conditions[?(@.type=="MemoryPressure")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status'
```

### 2. Node のリソース確認

```bash
# Node のリソース使用量
kubectl top nodes

# 各 Node の Allocatable リソース
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,CPU-ALLOC:.status.allocatable.cpu,MEM-ALLOC:.status.allocatable.memory,PODS:.status.allocatable.pods'

# Node 上の Pod 一覧
kubectl get pods --all-namespaces --field-selector spec.nodeName=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') -o wide
```

### 3. cordon / drain / uncordon

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# ① cordon: Node をスケジュール不可にする（既存 Pod は残る）
kubectl cordon $NODE
kubectl get nodes  # → SchedulingDisabled になる

# ② drain: Node 上の Pod を安全に退避（メンテナンス前に実行）
#   --ignore-daemonsets: DaemonSet の Pod は無視
#   --delete-emptydir-data: emptyDir のデータ削除を許可
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data

# ③ uncordon: Node をスケジュール可能に戻す（メンテナンス後）
kubectl uncordon $NODE
kubectl get nodes  # → Ready に戻る
```

### 4. kubelet のトラブルシューティング（kubeadm 環境）

```bash
# ※ AKS では Node に SSH するのは非推奨。CKA 試験向けの知識として覚える。

# kubelet のステータスを確認
# systemctl status kubelet

# kubelet のログを確認
# journalctl -u kubelet -f
# journalctl -u kubelet --since "5 minutes ago"

# kubelet を再起動
# systemctl restart kubelet

# kubelet の設定ファイル
# cat /var/lib/kubelet/config.yaml
```

### 5. AKS Node のトラブルシューティング

```bash
# AKS の Node の状態を Azure 側から確認
az aks show --resource-group rg-aks-microservices --name aks-microservices \
  --query agentPoolProfiles -o table

# VMSS の状態を確認
# az vmss list-instances --resource-group MC_rg-aks-microservices_aks-microservices_japaneast -o table

# Node を再イメージ（AKS 固有）
# az aks nodepool upgrade --resource-group rg-aks-microservices --cluster-name aks-microservices --name nodepool1 --node-image-only
```

### 🧹 クリーンアップ

```bash
# uncordon を忘れずに実行
kubectl uncordon $NODE

# Node の状態が Ready に戻ったことを確認
kubectl get nodes
```

---

## CKA 試験チェックリスト

- [ ] `kubectl describe node` で Conditions / Events を読める
- [ ] `kubectl cordon` / `drain` / `uncordon` の順序を理解
- [ ] drain のオプション（`--ignore-daemonsets`, `--delete-emptydir-data`）
- [ ] `systemctl status kubelet` / `journalctl -u kubelet` を知っている
- [ ] Node NotReady の原因調査手順
