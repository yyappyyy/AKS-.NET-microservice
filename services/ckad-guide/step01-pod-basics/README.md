# Step 01: Pod の基本操作

## 学習目標

- Pod を `kubectl run` で作成できる
- YAML マニフェストで Pod を定義できる
- `--dry-run=client -o yaml` で YAML を素早く生成できる
- Pod のライフサイクル (Pending → Running → Succeeded/Failed) を理解する

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-pod
```

## 2. kubectl run で Pod を素早く作成

```bash
# nginx Pod を即座に起動
kubectl run nginx-quick --image=nginx:1.27 -n ckad-pod

# 状態確認
kubectl get pods -n ckad-pod -o wide

# Pod の詳細を確認
kubectl describe pod nginx-quick -n ckad-pod
```

## 3. --dry-run=client -o yaml でマニフェスト生成

```bash
# YAML を生成 (作成はしない)
kubectl run nginx-gen --image=nginx:1.27 --port=80 \
  --dry-run=client -o yaml

# ファイルに保存
kubectl run nginx-gen --image=nginx:1.27 --port=80 \
  --dry-run=client -o yaml > /tmp/nginx-pod.yaml

# 確認してから適用
cat /tmp/nginx-pod.yaml
kubectl apply -f /tmp/nginx-pod.yaml -n ckad-pod
```

## 4. YAML マニフェストで Pod 作成

```yaml
# pod-manual.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-server
  namespace: ckad-pod
  labels:
    app: web
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    env:
    - name: APP_ENV
      value: "development"
    - name: APP_VERSION
      value: "1.0"
```

```bash
kubectl apply -f pod-manual.yaml
kubectl get pods -n ckad-pod --show-labels
```

## 5. Pod 内でコマンド実行

```bash
# Pod 内のシェルに入る
kubectl exec -it web-server -n ckad-pod -- /bin/bash

# (Pod 内で) 環境変数を確認
echo $APP_ENV
echo $APP_VERSION
cat /etc/os-release
exit

# 1 回だけコマンドを実行
kubectl exec web-server -n ckad-pod -- curl -s localhost:80

# ファイルの中身を確認
kubectl exec web-server -n ckad-pod -- cat /usr/share/nginx/html/index.html
```

## 6. Pod のログ確認

```bash
kubectl logs web-server -n ckad-pod
kubectl logs web-server -n ckad-pod --tail=10
kubectl logs web-server -n ckad-pod -f   # フォロー (Ctrl+C で終了)
```

## 7. kubectl explain で仕様確認

```bash
# Pod のトップレベルフィールド
kubectl explain pod

# spec.containers のフィールド
kubectl explain pod.spec.containers

# env のフィールド
kubectl explain pod.spec.containers.env
```

## 8. busybox Pod でテスト

```bash
# busybox を一時的に起動してコマンド実行
kubectl run busybox-test --image=busybox:1.36 -n ckad-pod \
  --rm -it --restart=Never -- /bin/sh

# (busybox 内で)
wget -qO- http://web-server.ckad-pod.svc.cluster.local
nslookup web-server.ckad-pod.svc.cluster.local
exit
```

## 9. Pod を別の形式で出力

```bash
# JSON 形式
kubectl get pod web-server -n ckad-pod -o json | head -30

# JSONPath で特定フィールド取得
kubectl get pod web-server -n ckad-pod -o jsonpath='{.status.podIP}'
kubectl get pod web-server -n ckad-pod -o jsonpath='{.spec.containers[0].image}'

# カスタムカラム
kubectl get pods -n ckad-pod -o custom-columns="NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase"
```

## 10. Pod の削除と再作成

```bash
# 単一 Pod 削除
kubectl delete pod nginx-quick -n ckad-pod

# ラベルで絞り込んで削除
kubectl delete pods -l app=web -n ckad-pod

# 全 Pod 削除
kubectl delete pods --all -n ckad-pod
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-pod
```
