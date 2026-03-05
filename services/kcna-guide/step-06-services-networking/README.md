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
| **ClusterIP** | クラスター内部のみ | マイクロサービス間通信 ← **Product Catalog で使用** |
| **NodePort** | Node IP:Port (30000-32767) | 開発・テスト |
| **LoadBalancer** | **Azure Load Balancer** 経由 | 外部公開（AKS 推奨） |
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
    - port: 80                   # ← Service のポート
      targetPort: 8080           # ← Pod のポート（.NET が LISTEN）
```

## 実プロジェクトの Ingress

`k8s/product-catalog/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: product-catalog
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx          # ← Ingress Controller が必要
  rules:
    - http:
        paths:
          - path: /product-catalog(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: product-catalog
                port:
                  number: 80
```

> **Ingress を使うには Ingress Controller が必要。** AKS では NGINX Ingress Controller をアドオンで追加可能。

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
# Namespace を作成
kubectl apply -f k8s/base/

# 全リソース（Deployment, Service, ConfigMap, HPA, Ingress）をデプロイ
kubectl apply -f k8s/product-catalog/

# Pod が Running になるまで待つ
kubectl get pods -n product-catalog -w
# Ctrl+C で監視を終了
```

### 2. Service の動作を確認

```bash
# Service 一覧を表示
#   ClusterIP と PORT が表示される
kubectl get svc -n product-catalog

# Endpoints を確認（Service に紐づいている Pod の IP:Port）
#   → Pod が Ready でないと Endpoints に表示されない
kubectl get endpoints -n product-catalog

# Service の詳細（Selector, Port, Endpoints 等）
kubectl describe svc product-catalog -n product-catalog
```

### 3. ポートフォワードでアクセス

```bash
# ポートフォワード: ローカルの 8080 → Service の 80 → Pod の 8080
#   Ctrl+C で停止
kubectl port-forward -n product-catalog svc/product-catalog 8080:80
```

**別ターミナルで API をテスト:**

```bash
# ヘルスチェック
curl http://localhost:8080/healthz
# 期待値: Healthy

# 商品一覧
curl http://localhost:8080/api/products
# 期待値: []

# UI にアクセス（ブラウザで開く）
# http://localhost:8080/
```

### 4. Kubernetes DNS の確認

```bash
# クラスター内から DNS 名前解決をテスト
#   --rm : 完了後に Pod を自動削除
#   -it  : 対話モード
kubectl run dns-test --image=busybox --rm -it -- nslookup product-catalog.product-catalog.svc.cluster.local
# → IP アドレスが返れば DNS が正常に動作している
```

### 🧹 クリーンアップ

```bash
# ポートフォワードを停止: Ctrl+C

# Product Catalog の全リソースを削除
kubectl delete -f k8s/product-catalog/

# Namespace を削除（中のリソースも全て削除される）
kubectl delete -f k8s/base/

# 確認
kubectl get all -n product-catalog
# 「No resources found」と表示されれば OK
```

---

## KCNA 試験チェックリスト

- [ ] 4 つの Service タイプの違い（特に ClusterIP vs LoadBalancer）
- [ ] Label Selector で Pod を選択する仕組み
- [ ] port（Service）vs targetPort（Pod）の違い
- [ ] Ingress と Ingress Controller の関係
- [ ] Kubernetes DNS の命名規則（`<svc>.<ns>.svc.cluster.local`）
