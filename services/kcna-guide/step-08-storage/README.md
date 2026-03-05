# Step 08: ストレージ

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- Volume、PV、PVC の関係を理解する
- StorageClass とダイナミックプロビジョニングを理解する
- Access Modes と Reclaim Policy を理解する

---

## ストレージの全体像

```
クラスター管理者             開発者                Pod
┌──────────────┐          ┌──────────┐        ┌────────┐
│ StorageClass │──自動──▶ │   PVC    │──使用──▶│ Volume │
│ (AKS: managed│  作成    │ 「1GB欲しい」│       │ (Pod内)│
│  -csi)       │          └──────────┘        └────────┘
└──────────────┘
  ダイナミックプロビジョニング: PVC を作ると PV が自動作成される
```

## Volume タイプ

| タイプ | ライフサイクル | 説明 |
|--------|-------------|------|
| **emptyDir** | Pod と同じ | 一時ディレクトリ。Pod 削除でデータ消失 |
| **hostPath** | Node に依存 | Node のファイルシステムをマウント |
| **configMap / secret** | リソースと同じ | 設定をファイルとしてマウント |
| **persistentVolumeClaim** | PV に依存 | 永続ストレージ |

## Access Modes（試験に出る！）

| モード | 略称 | 説明 |
|--------|------|------|
| **ReadWriteOnce** | RWO | 1 つの Node から読み書き |
| ReadOnlyMany | ROX | 複数 Node から読み取りのみ |
| ReadWriteMany | RWX | 複数 Node から読み書き |

> Azure Disk = **RWO のみ**。RWX が必要なら Azure Files を使う。

## Reclaim Policy

| ポリシー | PVC 削除時 |
|----------|----------|
| **Delete** | PV もデータも削除（デフォルト） |
| **Retain** | PV とデータを保持 |

---

## AKS ハンズオン

### 1. StorageClass を確認

```bash
# AKS 組み込みの StorageClass
kubectl get storageclass

# 詳細（provisioner, reclaimPolicy, volumeBindingMode）
kubectl describe storageclass managed-csi

# デフォルトの StorageClass を確認
kubectl get storageclass -o custom-columns='NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class'
```

### 2. PVC を作成

```bash
# PVC を作成
kubectl apply -f services/kcna-guide/step-08-storage/pvc.yaml

# PVC の状態を確認
#   STATUS=Bound: PV が自動作成されてバインド済み
#   STATUS=Pending: WaitForFirstConsumer の場合、Pod 配置まで待機
kubectl get pvc

# 自動作成された PV を確認
kubectl get pv

# PVC の詳細（容量、Access Mode、StorageClass、バインド先 PV）
kubectl describe pvc demo-pvc

# PV の詳細（Azure Disk のリソース ID 等）
PV_NAME=$(kubectl get pvc demo-pvc -o jsonpath='{.spec.volumeName}')
kubectl describe pv $PV_NAME
```

### 3. emptyDir を体験

```bash
# emptyDir Volume を使う Pod を作成
kubectl run vol-demo --image=busybox --command -- sh -c \
  "echo 'Hello from emptyDir' > /data/test.txt && cat /data/test.txt && sleep 3600" \
  --overrides='{"spec":{"containers":[{"name":"vol-demo","image":"busybox","command":["sh","-c","echo Hello > /data/test.txt && cat /data/test.txt && sleep 3600"],"volumeMounts":[{"name":"tmp","mountPath":"/data"}]}],"volumes":[{"name":"tmp","emptyDir":{}}]}}'

# Pod 内のファイルを確認
kubectl exec vol-demo -- cat /data/test.txt
# 出力: Hello

# Pod を削除すると emptyDir の内容も消える
kubectl delete pod vol-demo
```

### 4. PVC を使う Pod を作成

```bash
# PVC を使う Pod（YAML を直接生成して apply）
kubectl run pvc-demo --image=busybox --command -- sh -c "echo 'Persistent!' > /mnt/data/test.txt && sleep 3600" \
  --overrides='{"spec":{"containers":[{"name":"pvc-demo","image":"busybox","command":["sh","-c","echo Persistent > /mnt/data/test.txt && sleep 3600"],"volumeMounts":[{"name":"storage","mountPath":"/mnt/data"}]}],"volumes":[{"name":"storage","persistentVolumeClaim":{"claimName":"demo-pvc"}}]}}'

# ファイルが書き込まれたことを確認
kubectl exec pvc-demo -- cat /mnt/data/test.txt
# 出力: Persistent

# PVC の状態を再確認（Bound のまま）
kubectl get pvc
```

### 🧹 クリーンアップ

```bash
# Pod を先に削除（PVC を使っている場合）
kubectl delete pod pvc-demo vol-demo --ignore-not-found

# PVC を削除（Delete Policy なら PV + Azure Disk も自動削除）
kubectl delete -f services/kcna-guide/step-08-storage/pvc.yaml

# 確認
kubectl get pvc
kubectl get pv
```

---

## KCNA 試験チェックリスト

- [ ] PV → PVC → Pod Volume の関係
- [ ] RWO / ROX / RWX の違い
- [ ] StorageClass でダイナミックプロビジョニング
- [ ] Delete vs Retain の Reclaim Policy
- [ ] emptyDir は Pod 削除でデータ消失
- [ ] Azure Disk = RWO、Azure Files = RWX
