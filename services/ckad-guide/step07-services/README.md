# Step 07: Service (ClusterIP / NodePort / LoadBalancer)

## 学習目標

- Service の 3 種類 (ClusterIP / NodePort / LoadBalancer) の違いを理解する
- `kubectl expose` で Service を素早く作成できる
- Service 経由で Pod にアクセスする方法を理解する
- DNS による Service 名前解決を確認できる

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-svc
```

## 2. テスト用 Deployment 作成

```bash
# nginx ベースの Web アプリ Deployment
kubectl create deployment web-app --image=nginx:1.27 --replicas=3 -n ckad-svc
kubectl get pods -n ckad-svc -o wide
```

## 3. ClusterIP Service (デフォルト)

```bash
# kubectl expose で ClusterIP Service 作成
kubectl expose deployment web-app --port=80 --target-port=80 \
  --name=web-clusterip -n ckad-svc

# 確認
kubectl get svc web-clusterip -n ckad-svc
kubectl describe svc web-clusterip -n ckad-svc

# Endpoints (バックエンドの Pod IP)
kubectl get endpoints web-clusterip -n ckad-svc
```

### クラスタ内からアクセステスト

```bash
# 一時的な Pod から Service にアクセス
kubectl run curl-test --image=curlimages/curl -n ckad-svc \
  --rm -it --restart=Never -- curl -s http://web-clusterip.ckad-svc.svc.cluster.local

# busybox で DNS 確認
kubectl run dns-test --image=busybox:1.36 -n ckad-svc \
  --rm -it --restart=Never -- nslookup web-clusterip.ckad-svc.svc.cluster.local
```

## 4. YAML で ClusterIP Service

```yaml
# clusterip-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-clusterip-yaml
  namespace: ckad-svc
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - port: 8080          # Service のポート
    targetPort: 80       # Pod のポート
    protocol: TCP
```

```bash
kubectl apply -f clusterip-svc.yaml
kubectl get svc web-clusterip-yaml -n ckad-svc

# ポート 8080 でアクセス
kubectl run curl-test2 --image=curlimages/curl -n ckad-svc \
  --rm -it --restart=Never -- curl -s http://web-clusterip-yaml:8080
```

## 5. NodePort Service

```bash
kubectl expose deployment web-app --port=80 --target-port=80 \
  --type=NodePort --name=web-nodeport -n ckad-svc

# NodePort 番号を確認
kubectl get svc web-nodeport -n ckad-svc
kubectl get svc web-nodeport -n ckad-svc -o jsonpath='{.spec.ports[0].nodePort}'
```

### YAML で NodePort Service

```yaml
# nodeport-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport-yaml
  namespace: ckad-svc
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080      # 30000-32767 の範囲
```

```bash
kubectl apply -f nodeport-svc.yaml
kubectl get svc web-nodeport-yaml -n ckad-svc
```

## 6. LoadBalancer Service (AKS)

```bash
kubectl expose deployment web-app --port=80 --target-port=80 \
  --type=LoadBalancer --name=web-lb -n ckad-svc

# EXTERNAL-IP が割り当てられるまで待機
kubectl get svc web-lb -n ckad-svc -w

# 外部 IP でアクセス
EXTERNAL_IP=$(kubectl get svc web-lb -n ckad-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Access: http://$EXTERNAL_IP"
curl -s http://$EXTERNAL_IP
```

## 7. Headless Service (ClusterIP: None)

```yaml
# headless-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
  namespace: ckad-svc
spec:
  clusterIP: None
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f headless-svc.yaml

# ClusterIP が None (各 Pod IP が直接返される)
kubectl get svc web-headless -n ckad-svc

# DNS 確認 — Pod の IP が返される
kubectl run dns-headless --image=busybox:1.36 -n ckad-svc \
  --rm -it --restart=Never -- nslookup web-headless.ckad-svc.svc.cluster.local
```

## 8. 複数ポートの Service

```yaml
# multi-port-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-multi-port
  namespace: ckad-svc
spec:
  selector:
    app: web-app
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
```

```bash
kubectl apply -f multi-port-svc.yaml
kubectl get svc web-multi-port -n ckad-svc
```

## 9. --dry-run で Service の YAML 生成

```bash
kubectl expose deployment web-app --port=80 --type=ClusterIP \
  --name=test-svc -n ckad-svc --dry-run=client -o yaml

kubectl create service clusterip test-svc2 --tcp=8080:80 \
  --dry-run=client -o yaml
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-svc
```
