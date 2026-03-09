# Step 05: ConfigMap と Secret

## 学習目標

- ConfigMap を作成し、環境変数・ファイルとして Pod にマウントできる
- Secret を作成し、安全に機密情報を渡せる
- `kubectl create configmap` / `kubectl create secret` のオプションを使いこなす
- ConfigMap / Secret の更新と Pod への反映を理解する

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-config
```

## 2. ConfigMap — リテラルから作成

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080 \
  --from-literal=LOG_LEVEL=info \
  -n ckad-config

# 確認
kubectl get configmap app-config -n ckad-config -o yaml
kubectl describe configmap app-config -n ckad-config
```

## 3. ConfigMap — ファイルから作成

```bash
# 設定ファイルを作成
cat <<'EOF' > /tmp/app.properties
database.host=db.example.com
database.port=5432
database.name=myapp
cache.ttl=300
feature.dark_mode=true
EOF

cat <<'EOF' > /tmp/nginx.conf
server {
    listen 80;
    server_name localhost;
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# ファイルから ConfigMap 作成
kubectl create configmap file-config \
  --from-file=/tmp/app.properties \
  --from-file=custom-nginx=/tmp/nginx.conf \
  -n ckad-config

kubectl get configmap file-config -n ckad-config -o yaml
```

## 4. Pod で ConfigMap を環境変数として使用

```yaml
# cm-env-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cm-env-pod
  namespace: ckad-config
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "env | sort && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-config    # 全キーを環境変数として注入
    env:
    - name: CUSTOM_VAR
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV       # 単一キーを指定
```

```bash
kubectl apply -f cm-env-pod.yaml

# 環境変数を確認
kubectl exec cm-env-pod -n ckad-config -- env | grep -E "APP_|LOG_|CUSTOM"
```

## 5. Pod で ConfigMap をボリュームマウント

```yaml
# cm-vol-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cm-vol-pod
  namespace: ckad-config
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
    - name: props-volume
      mountPath: /etc/app-config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: file-config
      items:
      - key: custom-nginx
        path: default.conf
  - name: props-volume
    configMap:
      name: file-config
      items:
      - key: app.properties
        path: app.properties
```

```bash
kubectl apply -f cm-vol-pod.yaml

# マウントされたファイルを確認
kubectl exec cm-vol-pod -n ckad-config -- cat /etc/nginx/conf.d/default.conf
kubectl exec cm-vol-pod -n ckad-config -- cat /etc/app-config/app.properties

# /health エンドポイント確認
kubectl exec cm-vol-pod -n ckad-config -- curl -s localhost/health
```

## 6. Secret — リテラルから作成

```bash
kubectl create secret generic db-secret \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=SuperSecret123 \
  --from-literal=DB_HOST=db.ckad-config.svc.cluster.local \
  -n ckad-config

# 確認 (値は base64 でエンコードされている)
kubectl get secret db-secret -n ckad-config -o yaml

# デコードして読む
kubectl get secret db-secret -n ckad-config \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d && echo
```

## 7. Pod で Secret を使用

```yaml
# secret-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
  namespace: ckad-config
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo DB=$DB_USER@$DB_HOST && sleep 3600"]
    envFrom:
    - secretRef:
        name: db-secret
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: db-secret
```

```bash
kubectl apply -f secret-pod.yaml

# 環境変数確認
kubectl exec secret-pod -n ckad-config -- env | grep DB_

# ボリュームマウント確認
kubectl exec secret-pod -n ckad-config -- ls /etc/secrets/
kubectl exec secret-pod -n ckad-config -- cat /etc/secrets/DB_PASSWORD
```

## 8. Immutable ConfigMap / Secret

```yaml
# immutable-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
  namespace: ckad-config
data:
  VERSION: "2.0"
immutable: true
```

```bash
kubectl apply -f immutable-cm.yaml

# 変更しようとするとエラーになる
kubectl patch configmap immutable-config -n ckad-config \
  -p '{"data":{"VERSION":"3.0"}}' || echo "ERROR: immutable!"
```

## 9. --dry-run で YAML 生成

```bash
# ConfigMap
kubectl create configmap test-cm --from-literal=key1=val1 \
  --dry-run=client -o yaml

# Secret
kubectl create secret generic test-sec --from-literal=pass=abc123 \
  --dry-run=client -o yaml
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-config
rm -f /tmp/app.properties /tmp/nginx.conf
```
