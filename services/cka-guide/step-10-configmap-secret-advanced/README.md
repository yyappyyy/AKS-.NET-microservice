# Step 10: ConfigMap & Secret 応用

> **CKA 配点: Storage — 10%**

## 学習目標

- ConfigMap / Secret を Pod に環境変数・ファイルとして注入できる
- Volume マウントによるファイル注入を設定できる
- immutable な ConfigMap を理解する

---

## AKS ハンズオン

### 1. ConfigMap の高度な使い方

```bash
kubectl create namespace cka-config

# ファイルから ConfigMap を作成
echo 'server { listen 80; location / { return 200 "Hello CKA"; } }' > /tmp/nginx.conf
kubectl create configmap nginx-config --from-file=/tmp/nginx.conf -n cka-config

# ConfigMap をファイルとして Pod にマウント
cat <<EOF | kubectl apply -n cka-config -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-custom
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: config
    configMap:
      name: nginx-config
EOF

# 設定が反映されたか確認
kubectl exec nginx-custom -n cka-config -- cat /etc/nginx/conf.d/nginx.conf
kubectl exec nginx-custom -n cka-config -- curl -s localhost
```

### 2. Secret を Volume マウント

```bash
# Secret を作成
kubectl create secret generic db-creds \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=secret123 \
  -n cka-config

# Secret をファイルとして Pod にマウント
cat <<EOF | kubectl apply -n cka-config -f -
apiVersion: v1
kind: Pod
metadata:
  name: secret-vol
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "ls -la /etc/creds && cat /etc/creds/DB_USER && sleep 3600"]
    volumeMounts:
    - name: creds
      mountPath: /etc/creds
      readOnly: true
  volumes:
  - name: creds
    secret:
      secretName: db-creds
EOF

# マウントされたファイルを確認
kubectl exec secret-vol -n cka-config -- ls /etc/creds
kubectl exec secret-vol -n cka-config -- cat /etc/creds/DB_PASS
```

### 3. 環境変数として注入（個別キー）

```bash
cat <<EOF | kubectl apply -n cka-config -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env | sort && sleep 3600"]
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: nginx-config
          key: nginx.conf
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-creds
          key: DB_PASS
EOF

kubectl exec env-demo -n cka-config -- env | grep -E "DATABASE|DB_"
```

### 🧹 クリーンアップ

```bash
kubectl delete namespace cka-config
```

---

## CKA 試験チェックリスト

- [ ] ConfigMap を Volume としてマウントできる
- [ ] Secret を Volume / 環境変数で注入できる
- [ ] `valueFrom.configMapKeyRef` / `secretKeyRef` を書ける
- [ ] `--from-file` で ConfigMap / Secret を作成できる
