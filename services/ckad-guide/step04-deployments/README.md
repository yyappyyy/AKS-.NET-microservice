# Step 04: Deployments とローリングアップデート

## 学習目標

- Deployment の作成・スケーリング・更新を行える
- ローリングアップデート戦略 (`maxSurge`, `maxUnavailable`) を理解する
- ロールバック (`kubectl rollout undo`) を実行できる
- Deployment の履歴を管理できる

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-deploy
```

## 2. kubectl create deployment で作成

```bash
# nginx Deployment を作成
kubectl create deployment web-app --image=nginx:1.27 --replicas=3 -n ckad-deploy

# 確認
kubectl get deployments -n ckad-deploy
kubectl get replicasets -n ckad-deploy
kubectl get pods -n ckad-deploy -o wide
kubectl describe deployment web-app -n ckad-deploy
```

## 3. YAML で Deployment を定義

```yaml
# web-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-v2
  namespace: ckad-deploy
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web-app-v2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # 最大 1 つ追加 Pod を作る
      maxUnavailable: 1     # 最大 1 つ Pod が利用不可
  template:
    metadata:
      labels:
        app: web-app-v2
        version: v1
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
          limits:
            cpu: 100m
            memory: 128Mi
```

```bash
kubectl apply -f web-deployment.yaml
kubectl get deployment web-app-v2 -n ckad-deploy
kubectl get pods -n ckad-deploy -l app=web-app-v2
```

## 4. スケーリング

```bash
# スケールアウト
kubectl scale deployment web-app-v2 -n ckad-deploy --replicas=6
kubectl get pods -n ckad-deploy -l app=web-app-v2

# スケールイン
kubectl scale deployment web-app-v2 -n ckad-deploy --replicas=3
kubectl get pods -n ckad-deploy -l app=web-app-v2
```

## 5. ローリングアップデート

```bash
# イメージを nginx:1.28 に更新 (--record で履歴記録)
kubectl set image deployment/web-app-v2 nginx=nginx:1.28 \
  -n ckad-deploy

# ロールアウト状態を監視
kubectl rollout status deployment/web-app-v2 -n ckad-deploy

# Pod が順番に更新される様子
kubectl get pods -n ckad-deploy -l app=web-app-v2 -w

# 更新されたイメージを確認
kubectl get deployment web-app-v2 -n ckad-deploy \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## 6. ロールアウト履歴の確認

```bash
# 履歴一覧
kubectl rollout history deployment/web-app-v2 -n ckad-deploy

# 特定リビジョンの詳細
kubectl rollout history deployment/web-app-v2 -n ckad-deploy --revision=1
kubectl rollout history deployment/web-app-v2 -n ckad-deploy --revision=2

# ReplicaSet で履歴を確認
kubectl get replicasets -n ckad-deploy -l app=web-app-v2 -o wide
```

## 7. ロールバック

```bash
# 直前のバージョンに戻す
kubectl rollout undo deployment/web-app-v2 -n ckad-deploy

# ロールバック確認
kubectl rollout status deployment/web-app-v2 -n ckad-deploy
kubectl get deployment web-app-v2 -n ckad-deploy \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# 特定リビジョンに戻す場合
kubectl rollout undo deployment/web-app-v2 -n ckad-deploy --to-revision=1
```

## 8. Deployment の一時停止・再開

```bash
# 一時停止 (複数の変更をまとめて適用する場合)
kubectl rollout pause deployment/web-app-v2 -n ckad-deploy

# 複数の変更を適用
kubectl set image deployment/web-app-v2 nginx=nginx:1.28 -n ckad-deploy
kubectl set resources deployment/web-app-v2 -n ckad-deploy \
  -c nginx --limits=cpu=200m,memory=256Mi

# 再開 (まとめて 1 回のロールアウトで反映)
kubectl rollout resume deployment/web-app-v2 -n ckad-deploy
kubectl rollout status deployment/web-app-v2 -n ckad-deploy
```

## 9. kubectl edit で直接編集

```bash
# エディタで Deployment を開いて編集
kubectl edit deployment web-app-v2 -n ckad-deploy
# → replicas を変更して保存
```

## 10. --dry-run で YAML 生成

```bash
kubectl create deployment test-deploy --image=httpd:2.4 --replicas=2 \
  --dry-run=client -o yaml
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-deploy
```
