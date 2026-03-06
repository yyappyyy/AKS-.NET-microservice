# Step 08: Ingress と CoreDNS

> **CKA 配点: Services & Networking — 20%**

## 学習目標

- Ingress リソースを作成・設定できる
- Ingress Controller の役割を理解する
- CoreDNS の設定を理解し、カスタマイズできる

---

## AKS ハンズオン

### 1. Ingress Controller のインストール

```bash
# Helm で NGINX Ingress Controller をインストール
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace --namespace ingress-nginx \
  --set controller.replicaCount=2

# External IP が割り当てられるまで待つ（1-2分）
kubectl get svc -n ingress-nginx -w

INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"
```

### 2. Ingress リソースを作成

```bash
kubectl create namespace cka-ingress

# バックエンドの Deployment + Service を作成
kubectl create deployment app1 --image=nginx -n cka-ingress
kubectl expose deployment app1 --port=80 -n cka-ingress

kubectl create deployment app2 --image=httpd -n cka-ingress
kubectl expose deployment app2 --port=80 -n cka-ingress

# パスベースの Ingress
cat <<EOF | kubectl apply -n cka-ingress -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app1
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
      - path: /app2
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
EOF

# Ingress の状態を確認
kubectl get ingress -n cka-ingress
kubectl describe ingress path-ingress -n cka-ingress

# テスト
curl http://$INGRESS_IP/app1
curl http://$INGRESS_IP/app2
```

### 3. CoreDNS の確認

```bash
# CoreDNS の Deployment を確認
kubectl get deployment coredns -n kube-system

# CoreDNS の ConfigMap（Corefile）を確認
kubectl get configmap coredns -n kube-system -o yaml

# DNS 名前解決のテスト
kubectl run dns-debug --image=busybox --rm -it -- nslookup kubernetes.default.svc.cluster.local

# Service の FQDN を確認
kubectl run dns-debug --image=busybox --rm -it -- nslookup app1.cka-ingress.svc.cluster.local
```

### 🧹 クリーンアップ

```bash
kubectl delete namespace cka-ingress
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx --ignore-not-found
helm repo remove ingress-nginx
```

---

## CKA 試験チェックリスト

- [ ] Ingress リソースを YAML で書ける（パスベース、ホストベース）
- [ ] ingressClassName を指定できる
- [ ] CoreDNS の ConfigMap（Corefile）を読める
- [ ] DNS のトラブルシューティング（`nslookup`）ができる
