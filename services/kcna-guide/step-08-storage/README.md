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
│ (AKS: managed│  作成    │ 「5GB欲しい」│       │ (Pod内)│
│  -csi)       │          └──────────┘        └────────┘
└──────────────┘
  ダイナミックプロビジョニング: PVC を作ると PV が自動作成される
```

## AKS の StorageClass（組み込み）

```bash
kubectl get storageclass
```

| StorageClass | Azure ディスク | 用途 |
|-------------|---------------|------|
| `managed` | Standard HDD | 開発・テスト |
| `managed-premium` | Premium SSD | 本番 |
| `managed-csi` | CSI ドライバー | **推奨** |

## Access Modes（試験に出る！）

| モード | 略称 | 説明 |
|--------|------|------|
| **ReadWriteOnce** | RWO | 1 つの Node から読み書き |
| ReadOnlyMany | ROX | 複数 Node から読み取りのみ |
| ReadWriteMany | RWX | 複数 Node から読み書き |

> Azure Disk は **RWO のみ**。RWX が必要なら Azure Files を使う。

## Reclaim Policy

| ポリシー | PVC 削除時の動作 |
|----------|-----------------|
| **Delete** | PV とデータも削除（StorageClass のデフォルト） |
| **Retain** | PV とデータを保持 |

---

## AKS ハンズオン

### 1. StorageClass を確認

```bash
# AKS に組み込みの StorageClass を一覧表示
#   managed-csi, managed-csi-premium 等が見える
kubectl get storageclass

# 特定の StorageClass の詳細（provisioner, reclaimPolicy 等）
kubectl describe storageclass managed-csi
```

### 2. PVC を作成してダイナミックプロビジョニングを体験

```bash
# PVC を作成（StorageClass: managed-csi, 1Gi, RWO）
kubectl apply -f services/kcna-guide/step-08-storage/pvc.yaml

# PVC の状態を確認
#   STATUS が Bound になれば PV が自動作成されてバインドされた
#   WaitForFirstConsumer の場合は Pod がスケジュールされるまで Pending
kubectl get pvc

# 自動作成された PV を確認
kubectl get pv

# PVC の詳細（容量、Access Mode、StorageClass、バインド先 PV 等）
kubectl describe pvc demo-pvc
```

### 🧹 クリーンアップ

```bash
# PVC を削除（Reclaim Policy が Delete なら PV と Azure Disk も自動削除される）
kubectl delete -f services/kcna-guide/step-08-storage/pvc.yaml

# PV が削除されたことを確認
kubectl get pvc
kubectl get pv
# demo-pvc が表示されなければ OK
```

---

## KCNA 試験チェックリスト

- [ ] PV → PVC → Pod Volume の関係
- [ ] RWO / ROX / RWX の違い
- [ ] StorageClass でダイナミックプロビジョニング
- [ ] Delete vs Retain の Reclaim Policy
- [ ] emptyDir は Pod 削除でデータ消失
