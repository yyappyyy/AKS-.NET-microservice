# Step 12: NetworkPolicy

## 学習目標

- NetworkPolicy でトラフィックを制御する方法を理解する
- Ingress (受信) / Egress (送信) ルールを設定できる
- ラベルセレクターで通信許可対象を指定できる
- Default Deny ポリシーを適用できる

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-netpol
kubectl label namespace ckad-netpol purpose=netpol-demo
```

## 2. テスト用 Pod と Service を作成

```bash
# Web サーバー (フロントエンド)
kubectl run frontend --image=nginx:1.27 -n ckad-netpol \
  --labels="app=frontend,tier=web"
kubectl expose pod frontend --port=80 -n ckad-netpol

# API サーバー (バックエンド)
kubectl run backend --image=nginx:1.27 -n ckad-netpol \
  --labels="app=backend,tier=api"
kubectl expose pod backend --port=80 -n ckad-netpol

# データベース
kubectl run database --image=nginx:1.27 -n ckad-netpol \
  --labels="app=database,tier=db"
kubectl expose pod database --port=80 -n ckad-netpol

# 確認
kubectl get pods,svc -n ckad-netpol --show-labels
```

## 3. 通信テスト (NetworkPolicy 適用前)

```bash
# frontend → backend (成功するはず)
kubectl exec frontend -n ckad-netpol -- curl -s --max-time 3 http://backend
echo "frontend → backend: OK"

# frontend → database (成功するはず)
kubectl exec frontend -n ckad-netpol -- curl -s --max-time 3 http://database
echo "frontend → database: OK"

# backend → database (成功するはず)
kubectl exec backend -n ckad-netpol -- curl -s --max-time 3 http://database
echo "backend → database: OK"
```

## 4. Default Deny All Ingress

```yaml
# deny-all-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: ckad-netpol
spec:
  podSelector: {}           # 全 Pod に適用
  policyTypes:
  - Ingress                 # Ingress のみ制限 (Egress は自由)
  # ingress を定義しない → 全受信拒否
```

```bash
kubectl apply -f deny-all-ingress.yaml

# 全ての通信が拒否される
kubectl exec frontend -n ckad-netpol -- curl -s --max-time 3 http://backend || echo "BLOCKED!"
kubectl exec backend -n ckad-netpol -- curl -s --max-time 3 http://database || echo "BLOCKED!"
```

## 5. Backend への通信を Frontend からのみ許可

```yaml
# allow-frontend-to-backend.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: ckad-netpol
spec:
  podSelector:
    matchLabels:
      app: backend           # backend Pod に適用
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend      # frontend からのみ許可
    ports:
    - protocol: TCP
      port: 80
```

```bash
kubectl apply -f allow-frontend-to-backend.yaml

# frontend → backend (許可)
kubectl exec frontend -n ckad-netpol -- curl -s --max-time 3 http://backend
echo "frontend → backend: OK"

# database → backend (拒否)
kubectl exec database -n ckad-netpol -- curl -s --max-time 3 http://backend || echo "BLOCKED!"
```

## 6. Database への通信を Backend からのみ許可

```yaml
# allow-backend-to-db.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: ckad-netpol
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 80
```

```bash
kubectl apply -f allow-backend-to-db.yaml

# backend → database (許可)
kubectl exec backend -n ckad-netpol -- curl -s --max-time 3 http://database
echo "backend → database: OK"

# frontend → database (拒否)
kubectl exec frontend -n ckad-netpol -- curl -s --max-time 3 http://database || echo "BLOCKED!"
```

## 7. Egress ルール — 外部通信の制限

```yaml
# egress-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: ckad-netpol
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database      # database への送信のみ許可
    ports:
    - protocol: TCP
      port: 80
  - to:                      # DNS を許可 (必須)
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

```bash
kubectl apply -f egress-policy.yaml

# backend → database (許可)
kubectl exec backend -n ckad-netpol -- curl -s --max-time 3 http://database
echo "backend → database: OK"

# backend → frontend (拒否)
kubectl exec backend -n ckad-netpol -- curl -s --max-time 3 http://frontend || echo "BLOCKED!"
```

## 8. Namespace セレクター

```yaml
# ns-selector.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: ckad-netpol
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring    # monitoring ラベルの Namespace から許可
```

```bash
kubectl apply -f ns-selector.yaml --dry-run=client -o yaml
```

## 9. NetworkPolicy の確認コマンド

```bash
# 全 NetworkPolicy 一覧
kubectl get networkpolicies -n ckad-netpol

# 詳細
kubectl describe networkpolicy deny-all-ingress -n ckad-netpol

# kubectl explain
kubectl explain networkpolicy.spec.ingress
kubectl explain networkpolicy.spec.egress
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-netpol
```
