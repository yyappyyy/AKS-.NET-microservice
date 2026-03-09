# Step 09: Volumes と PersistentVolumeClaim

## 学習目標

- Volume の種類 (`emptyDir`, `hostPath`, `configMap`, `secret`, `PVC`) を理解する
- PersistentVolume (PV) と PersistentVolumeClaim (PVC) の関係を理解する
- AKS の動的プロビジョニング (Azure Disk / Azure Files) を使える
- Pod をまたいでデータを永続化できる

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-vol
```

## 2. emptyDir — Pod 内の一時共有ボリューム

```yaml
# emptydir-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo
  namespace: ckad-vol
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      i=0
      while true; do
        echo "$(date) - Message $i" >> /data/messages.txt
        i=$((i+1))
        sleep 3
      done
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "tail -f /data/messages.txt"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
  volumes:
  - name: shared-data
    emptyDir: {}
```

```bash
kubectl apply -f emptydir-pod.yaml

# writer が書いたデータを reader が読めるか確認
kubectl logs emptydir-demo -n ckad-vol -c reader --tail=5

# emptyDir のサイズ制限
kubectl exec emptydir-demo -n ckad-vol -c writer -- df -h /data
```

## 3. emptyDir (メモリベース)

```yaml
# emptydir-memory.yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-mem
  namespace: ckad-vol
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'fast cache data' > /cache/data && cat /cache/data && sleep 3600"]
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir:
      medium: Memory     # tmpfs (RAM) を使用
      sizeLimit: 64Mi
```

```bash
kubectl apply -f emptydir-memory.yaml
kubectl exec emptydir-mem -n ckad-vol -- df -h /cache
kubectl exec emptydir-mem -n ckad-vol -- cat /cache/data
```

## 4. PersistentVolumeClaim (動的プロビジョニング)

```bash
# AKS で利用可能な StorageClass を確認
kubectl get storageclass
```

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
  namespace: ckad-vol
spec:
  accessModes:
  - ReadWriteOnce     # 1 つの Node から読み書き
  storageClassName: managed-csi   # AKS の Azure Disk
  resources:
    requests:
      storage: 1Gi
```

```bash
kubectl apply -f pvc.yaml

# PVC のステータスを確認 (Pending → Bound)
kubectl get pvc -n ckad-vol
kubectl describe pvc app-data-pvc -n ckad-vol
```

## 5. PVC を使う Pod

```yaml
# pvc-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-writer
  namespace: ckad-vol
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "Writing persistent data..."
      echo "Created at: $(date)" > /data/info.txt
      echo "Host: $(hostname)" >> /data/info.txt
      echo "Data written to PVC!"
      cat /data/info.txt
      sleep 3600
    volumeMounts:
    - name: persistent
      mountPath: /data
  volumes:
  - name: persistent
    persistentVolumeClaim:
      claimName: app-data-pvc
```

```bash
kubectl apply -f pvc-pod.yaml

# データが書き込まれたか確認
kubectl exec pvc-writer -n ckad-vol -- cat /data/info.txt

# PV を確認
kubectl get pv
kubectl describe pv $(kubectl get pvc app-data-pvc -n ckad-vol -o jsonpath='{.spec.volumeName}')
```

## 6. データの永続性テスト

```bash
# Pod を削除
kubectl delete pod pvc-writer -n ckad-vol

# 同じ PVC を使う新しい Pod を作成
kubectl run pvc-reader --image=busybox:1.36 -n ckad-vol \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "pvc-reader",
      "image": "busybox:1.36",
      "command": ["sh", "-c", "cat /data/info.txt && sleep 3600"],
      "volumeMounts": [{"name": "persistent", "mountPath": "/data"}]
    }],
    "volumes": [{
      "name": "persistent",
      "persistentVolumeClaim": {"claimName": "app-data-pvc"}
    }]
  }
}'

# 前の Pod で書いたデータが残っているか確認
kubectl logs pvc-reader -n ckad-vol
```

## 7. Azure Files (ReadWriteMany)

```yaml
# azurefile-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-data-pvc
  namespace: ckad-vol
spec:
  accessModes:
  - ReadWriteMany        # 複数 Node から読み書き可能
  storageClassName: azurefile-csi
  resources:
    requests:
      storage: 1Gi
```

```bash
kubectl apply -f azurefile-pvc.yaml
kubectl get pvc shared-data-pvc -n ckad-vol
```

## 8. kubectl explain で Volume フィールド確認

```bash
kubectl explain pod.spec.volumes
kubectl explain pod.spec.containers.volumeMounts
kubectl explain pvc.spec
kubectl explain pv.spec
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-vol

# PV が Retain ポリシーの場合は手動削除
kubectl get pv | grep Released
# kubectl delete pv <pv-name>
```
