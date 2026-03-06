# Step 04: etcd バックアップとリストア

> **CKA 配点: Cluster Architecture — 25%**
> **試験での出題確率: 非常に高い**

## 学習目標

- etcd の役割と重要性を理解する
- etcdctl でバックアップ・リストアを実行できる
- AKS での etcd 管理を理解する

---

## etcd とは

- Kubernetes の**全データ**を保存する分散 KV ストア
- Pod, Service, ConfigMap, Secret, RBAC... 全て etcd に保存
- etcd が失われる = クラスターの全設定が失われる

---

## etcdctl コマンド（CKA 試験頻出！）

> AKS では etcd はマネージドのため直接操作不可。
> CKA 試験は kubeadm 環境で出題されるため必ず覚える。

### バックアップ

```bash
# ① 環境変数の設定（試験で毎回必要）
export ETCDCTL_API=3

# ② etcd のバックアップを取得
#   --endpoints : etcd のアドレス（通常 https://127.0.0.1:2379）
#   --cacert    : CA 証明書
#   --cert      : クライアント証明書
#   --key       : クライアント秘密鍵
etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# ③ バックアップの検証
etcdctl snapshot status /tmp/etcd-backup.db --write-table
```

### リストア

```bash
# ④ etcd をリストア（新しいデータディレクトリに復元）
etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored

# ⑤ etcd の Static Pod マニフェストで data-dir を変更
# vi /etc/kubernetes/manifests/etcd.yaml
#   volumes:
#     - hostPath:
#         path: /var/lib/etcd-restored  ← ここを変更
#   （kubelet が自動で etcd Pod を再起動する）
```

### 証明書パス（暗記！）

| ファイル | パス |
|---------|------|
| CA 証明書 | `/etc/kubernetes/pki/etcd/ca.crt` |
| サーバー証明書 | `/etc/kubernetes/pki/etcd/server.crt` |
| サーバーキー | `/etc/kubernetes/pki/etcd/server.key` |

### etcd の Pod から証明書パスを確認する方法

```bash
# etcd の Static Pod の YAML から証明書パスを取得
# cat /etc/kubernetes/manifests/etcd.yaml | grep -E 'cert|key|trusted'
# または
# kubectl describe pod etcd-controlplane -n kube-system | grep -E 'cert|key|ca'
```

---

## AKS ハンズオン（etcd に保存されているデータの確認）

AKS では etcd を直接操作できませんが、kubectl を通じて etcd のデータを確認できます。

### 1. クラスター内のリソース数を確認

```bash
# 全リソースの数（= etcd に保存されているオブジェクト数の概算）
kubectl get all -A --no-headers | wc -l

# Namespace ごとの Pod 数
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c | sort -rn

# ConfigMap の数
kubectl get configmap -A --no-headers | wc -l

# Secret の数
kubectl get secret -A --no-headers | wc -l

# Deployment の数
kubectl get deployment -A --no-headers | wc -l
```

### 2. リソースのバックアップ（kubectl ベース）

```bash
# 特定 Namespace の全リソースを YAML にエクスポート（簡易バックアップ）
kubectl create namespace etcd-demo

# テスト用リソースを作成
kubectl create deployment backup-test --image=nginx --replicas=2 -n etcd-demo
kubectl expose deployment backup-test --port=80 -n etcd-demo
kubectl create configmap backup-config --from-literal=KEY=VALUE -n etcd-demo
kubectl create secret generic backup-secret --from-literal=PASS=secret -n etcd-demo

# 確認
kubectl get all,configmap,secret -n etcd-demo

# Namespace 内の主要リソースを YAML でバックアップ
kubectl get deployment,service,configmap -n etcd-demo -o yaml > /tmp/etcd-demo-backup.yaml

# バックアップの内容を確認
cat /tmp/etcd-demo-backup.yaml | head -30
```

### 3. バックアップからリストア（kubectl ベース）

```bash
# リソースを削除
kubectl delete deployment backup-test -n etcd-demo
kubectl delete service backup-test -n etcd-demo

# 削除されたことを確認
kubectl get all -n etcd-demo

# バックアップからリストア
kubectl apply -f /tmp/etcd-demo-backup.yaml

# 復元されたことを確認
kubectl get all -n etcd-demo
```

### 4. AKS のクラスターバックアップ

```bash
# AKS クラスターの情報を確認
az aks show --resource-group rg-aks-microservices --name aks-microservices \
  --query '{version:kubernetesVersion,provisioningState:provisioningState}' -o table

# AKS ではバックアップは Azure が自動実行
# 手動でクラスターを再作成する場合は scripts/setup-azure.ps1 を使用
```

### 🧹 クリーンアップ

```bash
# テスト用 Namespace を削除（中のリソースも全て消える）
kubectl delete namespace etcd-demo

# バックアップファイルを削除
rm -f /tmp/etcd-demo-backup.yaml 2>/dev/null
# PowerShell: Remove-Item /tmp/etcd-demo-backup.yaml -ErrorAction SilentlyContinue

# 確認
kubectl get namespace | grep etcd
```

---

## CKA 試験チェックリスト

- [ ] `ETCDCTL_API=3` を最初に設定
- [ ] `etcdctl snapshot save` と 3 つの証明書オプション（`--cacert`, `--cert`, `--key`）
- [ ] `etcdctl snapshot restore --data-dir=<new-path>` でリストア
- [ ] リストア後に etcd Static Pod の `hostPath` を変更
- [ ] 証明書パスを `describe pod etcd-*` で確認する方法
