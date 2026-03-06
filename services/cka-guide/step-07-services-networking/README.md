# Step 07: Service とネットワーキング

> **CKA 配点: Services & Networking — 20%**

## 学習目標

- ClusterIP / NodePort / LoadBalancer Service を作成できる
- Service のトラブルシューティングができる
- NetworkPolicy を作成・テストできる

---

## AKS ハンズオン

### 1. Service の作成（全タイプ）

```bash
kubectl create namespace cka-network

# Deployment を作成
kubectl create deployment web --image=nginx --replicas=3 -n cka-network

# Pod が Running になるまで待つ
kubectl get pods -n cka-network -w

# ① ClusterIP Service（デフォルト — クラスター内部のみ）
kubectl expose deployment web --port=80 --target-port=80 \
  --name=web-clusterip -n cka-network

# ② NodePort Service（Node の IP:Port で外部アクセス）
kubectl expose deployment web --port=80 --target-port=80 \
  --type=NodePort --name=web-nodeport -n cka-network

# ③ LoadBalancer Service（Azure LB 経由で外部公開）
kubectl expose deployment web --port=80 --target-port=80 \
  --type=LoadBalancer --name=web-lb -n cka-network

# 全 Service を確認
kubectl get svc -n cka-network
```

### 2. Service の詳細確認

```bash
# Endpoints（Service → Pod の紐づけ）を確認
kubectl get endpoints -n cka-network

# 特定 Service の詳細
kubectl describe svc web-clusterip -n cka-network

# Service の YAML を生成（カスタマイズ用）
kubectl get svc web-clusterip -n cka-network -o yaml

# Service の Selector を確認
kubectl get svc web-clusterip -n cka-network -o jsonpath='{.spec.selector}'

# 一致する Pod を確認
kubectl get pods -n cka-network -l app=web -o wide
```

### 3. Service のテスト

```bash
# ClusterIP — クラスター内部からのテスト
kubectl run test-curl --image=curlimages/curl --rm -it -n cka-network \
  -- curl -s http://web-clusterip

# NodePort — NodePort の番号を確認
NODEPORT=$(kubectl get svc web-nodeport -n cka-network -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort: $NODEPORT"

# LoadBalancer — External IP を確認
kubectl get svc web-lb -n cka-network -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 4. Service のトラブルシューティング

```bash
# よくある問題: Endpoints が空 → Selector が Pod に一致していない

# ① Service の Selector を確認
kubectl get svc web-clusterip -n cka-network -o jsonpath='{.spec.selector}'

# ② Pod のラベルを確認
kubectl get pods -n cka-network --show-labels

# ③ Endpoints を確認（空なら紐づけに問題がある）
kubectl get endpoints web-clusterip -n cka-network

# ④ Pod 内から直接テスト
kubectl exec -it <pod-name> -n cka-network -- curl localhost:80
```

### 5. NetworkPolicy

```bash
# デフォルト: 全通信許可

# 全 Ingress を拒否するデフォルトポリシー
cat <<EOF | kubectl apply -n cka-network -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# テスト（ブロックされる）
kubectl run test-block --image=curlimages/curl --rm -it -n cka-network \
  -- curl -s --max-time 3 http://web-clusterip 2>&1 || echo "BLOCKED"

# 特定 Pod からのみ許可
cat <<EOF | kubectl apply -n cka-network -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-client
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: client
    ports:
    - port: 80
EOF

# client ラベルの Pod は許可される
kubectl run allowed --image=curlimages/curl --rm -it -n cka-network \
  --labels="role=client" -- curl -s --max-time 3 http://web-clusterip
```

### 🧹 クリーンアップ

```bash
kubectl delete namespace cka-network
```

---

## CKA 試験チェックリスト

- [ ] `kubectl expose` で全タイプの Service を作成できる
- [ ] Service の Endpoints が空の場合のデバッグ手順
- [ ] NetworkPolicy で Ingress/Egress を制御できる
- [ ] デフォルト拒否ポリシーを書ける
- [ ] `--dry-run=client -o yaml` で Service の YAML を素早く生成
