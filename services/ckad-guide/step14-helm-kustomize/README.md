# Step 14: Helm と Kustomize

## 学習目標

- Helm チャートの構成とコマンドを理解する
- `helm install` / `upgrade` / `rollback` を実行できる
- Kustomize で環境ごとのオーバーレイを管理できる
- `kubectl apply -k` でデプロイできる

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-helm
```

## 2. Helm の基本コマンド

```bash
# Helm バージョン確認
helm version

# リポジトリ追加
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# チャート検索
helm search repo nginx
helm search repo bitnami/nginx --versions | head -10
```

## 3. Helm install

```bash
# nginx をインストール
helm install my-nginx bitnami/nginx \
  --namespace ckad-helm \
  --set replicaCount=2 \
  --set service.type=ClusterIP

# 確認
helm list -n ckad-helm
kubectl get all -n ckad-helm
```

## 4. Helm の値を確認・カスタマイズ

```bash
# デフォルト値を確認
helm show values bitnami/nginx | head -50

# カスタム values ファイル作成
cat <<'EOF' > /tmp/my-values.yaml
replicaCount: 3
service:
  type: ClusterIP
  port: 8080
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
EOF

# values ファイルでアップグレード
helm upgrade my-nginx bitnami/nginx \
  --namespace ckad-helm \
  -f /tmp/my-values.yaml

# 変更確認
helm list -n ckad-helm
kubectl get pods -n ckad-helm
kubectl get svc -n ckad-helm
```

## 5. Helm rollback

```bash
# リリース履歴
helm history my-nginx -n ckad-helm

# ロールバック (リビジョン 1 へ)
helm rollback my-nginx 1 -n ckad-helm

# 確認
helm history my-nginx -n ckad-helm
kubectl get pods -n ckad-helm
```

## 6. Helm テンプレートの確認

```bash
# レンダリング結果を確認 (デプロイはしない)
helm template my-nginx bitnami/nginx \
  --namespace ckad-helm \
  --set replicaCount=2 | head -80

# dry-run で確認
helm install test-release bitnami/nginx \
  --namespace ckad-helm \
  --dry-run --debug 2>&1 | head -50
```

## 7. Helm uninstall

```bash
helm uninstall my-nginx -n ckad-helm
helm list -n ckad-helm
```

---

## 8. Kustomize — ディレクトリ構成

```
kustomize-demo/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

### Base マニフェスト作成

```bash
mkdir -p /tmp/kustomize-demo/base
mkdir -p /tmp/kustomize-demo/overlays/dev
mkdir -p /tmp/kustomize-demo/overlays/prod
```

```bash
# base/deployment.yaml
cat <<'EOF' > /tmp/kustomize-demo/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
EOF

# base/service.yaml
cat <<'EOF' > /tmp/kustomize-demo/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
EOF

# base/kustomization.yaml
cat <<'EOF' > /tmp/kustomize-demo/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
commonLabels:
  managed-by: kustomize
EOF
```

### Dev オーバーレイ

```bash
cat <<'EOF' > /tmp/kustomize-demo/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
namespace: ckad-helm
namePrefix: dev-
commonLabels:
  env: dev
patches:
- target:
    kind: Deployment
    name: web-app
  patch: |
    - op: replace
      path: /spec/replicas
      value: 2
EOF
```

### Prod オーバーレイ

```bash
cat <<'EOF' > /tmp/kustomize-demo/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
namespace: ckad-helm
namePrefix: prod-
commonLabels:
  env: prod
patches:
- target:
    kind: Deployment
    name: web-app
  patch: |
    - op: replace
      path: /spec/replicas
      value: 5
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/cpu
      value: 200m
EOF
```

## 9. Kustomize の使用

```bash
# Dev 環境のマニフェストをプレビュー
kubectl kustomize /tmp/kustomize-demo/overlays/dev

# Dev 環境にデプロイ
kubectl apply -k /tmp/kustomize-demo/overlays/dev

# 確認
kubectl get deploy,svc -n ckad-helm -l env=dev

# Prod 環境のプレビュー
kubectl kustomize /tmp/kustomize-demo/overlays/prod

# Prod 環境にデプロイ
kubectl apply -k /tmp/kustomize-demo/overlays/prod
kubectl get deploy,svc -n ckad-helm -l env=prod
```

## 10. Kustomize で削除

```bash
# Dev 環境を削除
kubectl delete -k /tmp/kustomize-demo/overlays/dev

# Prod 環境を削除
kubectl delete -k /tmp/kustomize-demo/overlays/prod
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-helm
rm -rf /tmp/kustomize-demo /tmp/my-values.yaml
```
