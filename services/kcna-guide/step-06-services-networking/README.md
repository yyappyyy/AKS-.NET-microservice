# Step 06: Service とネットワーキング

> **KCNA 配点: Kubernetes Fundamentals 46% + Container Orchestration 22%**

## 学習目標

- Service の 4 タイプを理解する
- Label Selector による Pod 選択の仕組みを理解する
- Ingress の役割を理解する
- Kubernetes DNS を理解する

---

## なぜ Service が必要か

Pod の IP は一時的（再作成で変わる）。Service は**安定したアクセス先**を提供:

```
           Service (10.0.0.1:80)  ← 安定した VIP
              │ Label Selector: app=product-catalog
    ┌─────────┼─────────┐
    ▼         ▼         ▼
Pod(10.244.0.5) Pod(10.244.1.3) Pod(10.244.2.7)  ← IP は変動
```

## Service タイプ

| タイプ | アクセス範囲 | AKS での用途 |
|--------|-------------|-------------|
| **ClusterIP** | クラスター内部のみ | マイクロサービス間通信 ← **Product Catalog** |
| **NodePort** | Node IP:Port (30000-32767) | 開発・テスト |
| **LoadBalancer** | **Azure LB** 経由 | 外部公開（AKS 推奨） |
| **ExternalName** | 外部 DNS の CNAME | 外部サービス参照 |

## 実プロジェクトの Service

`k8s/product-catalog/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: product-catalog          # ← DNS 名になる
  namespace: product-catalog
spec:
  type: ClusterIP                # ← クラスター内部のみ
  selector:
    app: product-catalog         # ← この label の Pod にルーティング
  ports:
    - port: 80                   # ← Service のポート（アクセスする側）
      targetPort: 8080           # ← Pod のポート（.NET が LISTEN）
```

> **port vs targetPort:** Service に `80` でアクセスすると、Pod の `8080` に転送される。

## Ingress

L7 (HTTP/HTTPS) でパスベース・ホストベースのルーティング:

```yaml
spec:
  ingressClassName: nginx          # ← Ingress Controller が別途必要
  rules:
    - host: shop.example.com
      http:
        paths:
          - path: /api/products
            backend:
              service:
                name: product-catalog
                port:
                  number: 80
```

> **Ingress リソースだけでは動作しない。Ingress Controller（NGINX 等）が必要。**

---

## Kubernetes DNS

```
<service>.<namespace>.svc.cluster.local

例: product-catalog.product-catalog.svc.cluster.local
    ↑ Service名       ↑ Namespace名
```

同じ Namespace 内なら Service 名だけで OK:
```bash
curl http://product-catalog/api/products
```

---

## AKS ハンズオン

### 1. Product Catalog をデプロイ

```bash
kubectl apply -f k8s/base/
kubectl apply -f k8s/product-catalog/

# Pod が Running になるまで待つ（Ctrl+C で終了）
kubectl get pods -n product-catalog -w
```

### 2. Service を確認

```bash
# Service 一覧（ClusterIP, PORT）
kubectl get svc -n product-catalog

# Service の全情報を YAML で確認
kubectl get svc product-catalog -n product-catalog -o yaml

# Endpoints（Service に紐づく Pod の IP:Port）
kubectl get endpoints -n product-catalog

# Service の詳細（Selector, Events）
kubectl describe svc product-catalog -n product-catalog

# 全 Service タイプの Service を一覧
kubectl get svc -A
```

### 3. ポートフォワードでアクセス

```bash
# ポートフォワード: ローカル 8080 → Service 80 → Pod 8080
kubectl port-forward -n product-catalog svc/product-catalog 8080:80
# Ctrl+C で停止
```

**別ターミナルでテスト:**

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/api/products
# ブラウザ: http://localhost:8080/
```

### 4. Pod に直接ポートフォワード

```bash
# Pod 名を取得
POD=$(kubectl get pods -n product-catalog -o jsonpath='{.items[0].metadata.name}')

# Pod に直接ポートフォワード（Service を経由しない）
kubectl port-forward -n product-catalog pod/$POD 8081:8080

# 別ターミナルで
curl http://localhost:8081/healthz
```

### 5. DNS の確認

```bash
# クラスター内から DNS を確認
kubectl run dns-test --image=busybox --rm -it -- nslookup product-catalog.product-catalog.svc.cluster.local

# クラスター内からの HTTP アクセスを確認
kubectl run curl-test --image=curlimages/curl --rm -it -- curl -s http://product-catalog.product-catalog.svc/api/products

# 短縮名でのアクセス（同じ Namespace 内のみ）
kubectl run curl-test --image=curlimages/curl --rm -it -n product-catalog -- curl -s http://product-catalog/healthz
```

### 6. LoadBalancer タイプの Service を体験

```bash
# nginx を LoadBalancer で公開（Azure LB が作成される）
kubectl create deployment lb-demo --image=nginx
kubectl expose deployment lb-demo --port=80 --type=LoadBalancer

# EXTERNAL-IP が表示されるまで待つ（1〜2 分）
kubectl get svc lb-demo -w

# EXTERNAL-IP にブラウザでアクセス
# curl http://<EXTERNAL-IP>

# 削除
kubectl delete svc lb-demo
kubectl delete deployment lb-demo
```

### 7. Service の Selector を確認

```bash
# Service がどの Pod を選択しているか確認
kubectl get svc product-catalog -n product-catalog -o jsonpath='{.spec.selector}'

# 一致する Pod を確認
kubectl get pods -n product-catalog -l app=product-catalog

# ラベルが一致しない Pod はEndpoints から除外される
```

### 🧹 クリーンアップ

```bash
# ポートフォワード停止: Ctrl+C

# LoadBalancer デモを削除（既に上で削除済みなら不要）
kubectl delete svc lb-demo --ignore-not-found
kubectl delete deployment lb-demo --ignore-not-found

# Product Catalog を削除する場合
kubectl delete -f k8s/product-catalog/
kubectl delete -f k8s/base/

# 確認
kubectl get all -n product-catalog
```

---

## KCNA 試験チェックリスト

- [ ] 4 つの Service タイプの違い（特に ClusterIP vs LoadBalancer）
- [ ] Label Selector で Pod を選択する仕組み
- [ ] port（Service 側）vs targetPort（Pod 側）の違い
- [ ] Ingress と Ingress Controller の関係（Controller が別途必要）
- [ ] Kubernetes DNS の命名規則（`<svc>.<ns>.svc.cluster.local`）
- [ ] Endpoints が Pod の IP:Port のリスト
