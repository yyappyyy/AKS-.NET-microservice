# Step 09: ストレージ

> **CKA 配点: Storage — 10%**

## 学習目標

- PV / PVC を作成し、Pod にマウントできる
- StorageClass を理解し、ダイナミックプロビジョニングを使える
- Volume の拡張ができる

---

## AKS ハンズオン

### 1. PVC とダイナミックプロビジョニング

```bash
kubectl create namespace cka-storage

# PVC を作成（StorageClass が自動で PV を作成する）
cat <<EOF | kubectl apply -n cka-storage -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: managed-csi
EOF

# PVC と PV を確認（Bound になるまで待つ）
kubectl get pvc -n cka-storage
kubectl get pv

# PVC の詳細
kubectl describe pvc my-pvc -n cka-storage
```

### 2. Pod に PVC をマウント

```bash
cat <<EOF | kubectl apply -n cka-storage -f -
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo 'CKA Storage Test' > /data/test.txt && cat /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: my-pvc
EOF

# ファイルが書き込まれたことを確認
kubectl exec pvc-pod -n cka-storage -- cat /data/test.txt

# Pod を削除しても PVC/PV のデータは残る
kubectl delete pod pvc-pod -n cka-storage
kubectl get pvc -n cka-storage  # まだ Bound のまま
```

### 3. 静的 PV を作成

```bash
# 管理者が PV を手動で作成
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
EOF

# PV 用の PVC を作成
cat <<EOF | kubectl apply -n cka-storage -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: manual-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
EOF

# PV と PVC がバインドされたか確認
kubectl get pv manual-pv
kubectl get pvc manual-pvc -n cka-storage
```

### 4. StorageClass の確認

```bash
# AKS 組み込みの StorageClass 一覧
kubectl get storageclass

# 各 StorageClass の詳細
kubectl describe storageclass managed-csi

# デフォルト StorageClass を確認
kubectl get storageclass -o custom-columns=\
'NAME:.metadata.name,PROVISIONER:.provisioner,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class'
```

### 🧹 クリーンアップ

```bash
kubectl delete namespace cka-storage
kubectl delete pv manual-pv --ignore-not-found
```

---

## CKA 試験チェックリスト

- [ ] PVC の YAML を書ける（accessModes, storage, storageClassName）
- [ ] Pod に PVC を volumeMounts でマウントできる
- [ ] 静的 PV を作成してバインドできる
- [ ] AccessModes（RWO/ROX/RWX）を理解している
- [ ] Reclaim Policy（Delete/Retain）の違い
