# Step 08: Ingress

## 学習目標

- Ingress リソースの構成を理解する
- Ingress Controller (NGINX) のインストールと確認ができる
- パスベース・ホストベースのルーティングを設定できる
- TLS 終端の基本を理解する

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-ingress
```

## 2. Ingress Controller のインストール (AKS)

```bash
# NGINX Ingress Controller を Helm でインストール
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2

# 外部 IP が割り当てられるまで待機
kubectl get svc -n ingress-nginx -w
```

## 3. テスト用 Deployment & Service を作成

```bash
# アプリ A (nginx)
kubectl create deployment app-a --image=nginx:1.27 --replicas=2 -n ckad-ingress
kubectl expose deployment app-a --port=80 -n ckad-ingress

# アプリ B (httpd)
kubectl create deployment app-b --image=httpd:2.4 --replicas=2 -n ckad-ingress
kubectl expose deployment app-b --port=80 -n ckad-ingress

# 確認
kubectl get deploy,svc -n ckad-ingress
```

## 4. パスベースルーティング

```yaml
# path-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based
  namespace: ckad-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app-a
        pathType: Prefix
        backend:
          service:
            name: app-a
            port:
              number: 80
      - path: /app-b
        pathType: Prefix
        backend:
          service:
            name: app-b
            port:
              number: 80
```

```bash
kubectl apply -f path-ingress.yaml
kubectl get ingress -n ckad-ingress

# Ingress の EXTERNAL-IP を取得
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# アクセステスト
curl -s http://$INGRESS_IP/app-a
curl -s http://$INGRESS_IP/app-b
```

## 5. ホストベースルーティング

```yaml
# host-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-based
  namespace: ckad-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: app-a.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-a
            port:
              number: 80
  - host: app-b.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-b
            port:
              number: 80
```

```bash
kubectl apply -f host-ingress.yaml
kubectl get ingress host-based -n ckad-ingress

# Host ヘッダーを指定してテスト
curl -s -H "Host: app-a.example.com" http://$INGRESS_IP
curl -s -H "Host: app-b.example.com" http://$INGRESS_IP
```

## 6. Default Backend

```yaml
# default-backend-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: with-default
  namespace: ckad-ingress
spec:
  ingressClassName: nginx
  defaultBackend:
    service:
      name: app-a
      port:
        number: 80
  rules:
  - http:
      paths:
      - path: /special
        pathType: Prefix
        backend:
          service:
            name: app-b
            port:
              number: 80
```

```bash
kubectl apply -f default-backend-ingress.yaml

# / → app-a (default), /special → app-b
kubectl describe ingress with-default -n ckad-ingress
```

## 7. TLS 設定 (自己署名証明書)

```bash
# 自己署名証明書を作成
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=myapp.example.com"

# TLS Secret 作成
kubectl create secret tls myapp-tls \
  --cert=/tmp/tls.crt --key=/tmp/tls.key -n ckad-ingress
```

```yaml
# tls-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  namespace: ckad-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-a
            port:
              number: 80
```

```bash
kubectl apply -f tls-ingress.yaml
kubectl describe ingress tls-ingress -n ckad-ingress

# HTTPS でアクセス
curl -sk -H "Host: myapp.example.com" https://$INGRESS_IP
```

## 8. Ingress の確認コマンド

```bash
# 全 Ingress 一覧
kubectl get ingress -n ckad-ingress

# 詳細
kubectl describe ingress path-based -n ckad-ingress

# kubectl explain
kubectl explain ingress.spec.rules
kubectl explain ingress.spec.tls
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-ingress
rm -f /tmp/tls.key /tmp/tls.crt

# (Ingress Controller も不要なら)
# helm uninstall ingress-nginx -n ingress-nginx
# kubectl delete namespace ingress-nginx
```
