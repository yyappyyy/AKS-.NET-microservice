# Step 15: CKA 模擬問題（実技形式）

> CKA は**実技試験**です。以下の問題を実際に kubectl で解いてください。
> 制限時間の目安: 問題あたり **6〜8 分**

## 試験開始前の準備（毎回実施）

```bash
# エイリアス設定
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kd='kubectl describe'

# bash 補完
source <(kubectl completion bash)
complete -o default -F __start_kubectl k

# 練習用 Namespace
kubectl create namespace cka-exam
```

---

## 問題 1: Pod の作成（配点: 4%）

> **Namespace `cka-exam` に以下の条件で Pod を作成してください。**
> - Pod 名: `web-pod`
> - イメージ: `nginx:1.27`
> - ポート: `80`
> - ラベル: `tier=frontend`
> - リソース requests: CPU `100m`, Memory `128Mi`
> - リソース limits: CPU `250m`, Memory `256Mi`

<details>
<summary>💡 解答を見る</summary>

```bash
# YAML を生成してから編集
kubectl run web-pod --image=nginx:1.27 --port=80 \
  --labels="tier=frontend" \
  --dry-run=client -o yaml > /tmp/q1.yaml

# リソース制限を追加して apply
cat <<EOF | kubectl apply -n cka-exam -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    tier: frontend
  name: web-pod
spec:
  containers:
  - image: nginx:1.27
    name: web-pod
    ports:
    - containerPort: 80
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "250m"
        memory: "256Mi"
EOF

# 確認
kubectl get pod web-pod -n cka-exam -o wide
kubectl describe pod web-pod -n cka-exam | grep -A 6 "Limits\|Requests"
```

**ポイント:** `--dry-run=client -o yaml` で雛形を生成し、足りない部分を追加するのが最速。
</details>

---

## 問題 2: Deployment とスケーリング（配点: 7%）

> **以下の Deployment を作成し、操作してください。**
> 1. Namespace `cka-exam` に Deployment `web-deploy` を作成（nginx:1.27, replicas=3）
> 2. Service `web-svc` を作成（ClusterIP, port=80）
> 3. イメージを `nginx:1.28` にアップデート
> 4. レプリカ数を 5 にスケール

<details>
<summary>💡 解答を見る</summary>

```bash
# ① Deployment 作成
kubectl create deployment web-deploy --image=nginx:1.27 --replicas=3 -n cka-exam

# ② Service 作成
kubectl expose deployment web-deploy --port=80 --name=web-svc -n cka-exam

# ③ イメージ更新
kubectl set image deployment web-deploy nginx=nginx:1.28 -n cka-exam
kubectl rollout status deployment web-deploy -n cka-exam

# ④ スケール
kubectl scale deployment web-deploy --replicas=5 -n cka-exam

# 確認
kubectl get deploy,svc,pods -n cka-exam
```

**ポイント:** Imperative コマンドを使えば YAML 不要で素早く完了。
</details>

---

## 問題 3: RBAC（配点: 7%）

> **Namespace `cka-exam` で以下の RBAC を設定してください。**
> 1. Role `pod-manager` を作成: pods に対して get, list, create, delete を許可
> 2. ServiceAccount `deploy-bot` を作成
> 3. RoleBinding `deploy-bot-binding` で `deploy-bot` に `pod-manager` を紐づけ
> 4. `deploy-bot` として pods の作成が可能であることを確認

<details>
<summary>💡 解答を見る</summary>

```bash
# ① Role 作成
kubectl create role pod-manager \
  --verb=get,list,create,delete \
  --resource=pods \
  -n cka-exam

# ② ServiceAccount 作成
kubectl create serviceaccount deploy-bot -n cka-exam

# ③ RoleBinding 作成
kubectl create rolebinding deploy-bot-binding \
  --role=pod-manager \
  --serviceaccount=cka-exam:deploy-bot \
  -n cka-exam

# ④ 確認
kubectl auth can-i create pods -n cka-exam --as=system:serviceaccount:cka-exam:deploy-bot
# yes

kubectl auth can-i delete deployments -n cka-exam --as=system:serviceaccount:cka-exam:deploy-bot
# no（pods のみ許可なので）
```
</details>

---

## 問題 4: NetworkPolicy（配点: 7%）

> **Namespace `cka-exam` で、ラベル `app=db` の Pod への Ingress を、
> ラベル `app=web` の Pod からの port 3306 のみに制限してください。**

<details>
<summary>💡 解答を見る</summary>

```bash
cat <<EOF | kubectl apply -n cka-exam -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - port: 3306
      protocol: TCP
EOF

# 確認
kubectl get networkpolicy db-policy -n cka-exam -o yaml
```

**ポイント:** podSelector で対象 Pod を選び、ingress.from で送信元を制限する。
</details>

---

## 問題 5: PV / PVC（配点: 7%）

> 1. PVC `data-pvc` を作成: 2Gi, RWO, StorageClass `managed-csi`
> 2. Pod `data-pod` を作成: busybox, PVC を `/data` にマウント

<details>
<summary>💡 解答を見る</summary>

```bash
cat <<EOF | kubectl apply -n cka-exam -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: managed-csi
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo CKA > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: data-pvc
EOF

# 確認
kubectl get pvc data-pvc -n cka-exam
kubectl exec data-pod -n cka-exam -- cat /data/test.txt
```
</details>

---

## 問題 6: Node メンテナンス（配点: 7%）

> Node をメンテナンスモードにし、作業後に復帰させてください。

<details>
<summary>💡 解答を見る</summary>

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# ① cordon
kubectl cordon $NODE

# ② drain
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --force

# ③ （メンテナンス作業）

# ④ uncordon
kubectl uncordon $NODE

# 確認
kubectl get nodes
```
</details>

---

## 問題 7: Ingress（配点: 7%）

> Deployment `app-v1`（nginx）と `app-v2`（httpd）を作成し、
> Ingress で `/v1` → app-v1, `/v2` → app-v2 にルーティングしてください。

<details>
<summary>💡 解答を見る</summary>

```bash
kubectl create deployment app-v1 --image=nginx -n cka-exam
kubectl expose deployment app-v1 --port=80 -n cka-exam

kubectl create deployment app-v2 --image=httpd -n cka-exam
kubectl expose deployment app-v2 --port=80 -n cka-exam

cat <<EOF | kubectl apply -n cka-exam -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: app-v1
            port:
              number: 80
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: app-v2
            port:
              number: 80
EOF
```
</details>

---

## 問題 8: マルチコンテナ Pod（配点: 7%）

> Sidecar パターンの Pod を作成:
> - メイン: nginx（ポート 80）
> - Sidecar: busybox（5 秒ごとにログを共有 Volume に書き込み）

<details>
<summary>💡 解答を見る</summary>

```bash
cat <<EOF | kubectl apply -n cka-exam -f -
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-pod
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  - name: sidecar
    image: busybox
    command: ["sh", "-c", "while true; do date >> /html/index.html; sleep 5; done"]
    volumeMounts:
    - name: shared
      mountPath: /html
  volumes:
  - name: shared
    emptyDir: {}
EOF

# 確認
kubectl exec sidecar-pod -n cka-exam -c nginx -- curl -s localhost
kubectl logs sidecar-pod -n cka-exam -c sidecar --tail=5
```
</details>

---

## 問題 9: トラブルシューティング（配点: 13%）

> Deployment `broken-app` の Pod が起動しません。原因を特定し修復してください。

```bash
cat <<EOF | kubectl apply -n cka-exam -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken
  template:
    metadata:
      labels:
        app: broken
    spec:
      containers:
      - name: app
        image: ngnix:latest
        ports:
        - containerPort: 80
EOF
```

<details>
<summary>💡 解答を見る</summary>

```bash
# ① Pod の状態を確認
kubectl get pods -n cka-exam -l app=broken
# STATUS: ImagePullBackOff

# ② Events を確認
kubectl describe pod -n cka-exam -l app=broken | grep -A 3 Events
# Failed to pull image "ngnix:latest" → イメージ名のスペルミス！

# ③ 修復: イメージ名を修正
kubectl set image deployment broken-app app=nginx:latest -n cka-exam

# ④ 確認
kubectl rollout status deployment broken-app -n cka-exam
kubectl get pods -n cka-exam -l app=broken
# STATUS: Running, READY: 1/1
```

**ポイント:** `ngnix` → `nginx` のタイプミス。`kubectl describe` の Events が最大のヒント。
</details>

---

## 問題 10: etcd バックアップ（配点: 7%）

> etcd のスナップショットを `/tmp/etcd-backup.db` に保存してください。

<details>
<summary>💡 解答を見る</summary>

```bash
# CKA 試験環境（kubeadm）で実行するコマンド
export ETCDCTL_API=3

etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 検証
etcdctl snapshot status /tmp/etcd-backup.db --write-table
```

**ポイント:** 3 つの証明書オプション（`--cacert`, `--cert`, `--key`）を
忘れずに指定する。パスは `/etc/kubernetes/pki/etcd/` 配下。
</details>

---

## 🧹 全問題のクリーンアップ

```bash
kubectl delete namespace cka-exam

# Node を uncordon（問題 6 を実行した場合）
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl uncordon $NODE 2>/dev/null

kubectl get nodes
```

---

## 採点基準

| 正答数 | 得点率 | 判定 |
|--------|--------|------|
| 7+/10 | 66%+ | ✅ 合格ライン |
| 5-6/10 | 50-65% | ⚠️ 弱点を復習 |
| 4以下 | 40%以下 | ❌ 各 Step に戻って再学習 |

## 本番に向けて

1. **速度が命**: 1 問あたり 6〜8 分。Imperative コマンドで時間短縮
2. **公式ドキュメントを活用**: kubernetes.io/docs/ は試験中に参照可能
3. **`--dry-run=client -o yaml`** を多用して YAML 生成を高速化
4. **エイリアス設定**を試験開始直後に行う
5. [CKA 公式](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) で最新情報を確認
