# Step 15: 模擬試験 (15 問)

## 試験概要

- **時間**: 2 時間
- **問題数**: 16 問 (CKAD 本番)
- **この模擬試験**: 15 問 / 目標 90 分
- **合格ライン**: 66%
- **環境**: Kubernetes クラスター (AKS)

> 💡 各問に制限時間の目安をつけています。試験本番を意識して時間を測りましょう。

---

## セットアップ

```bash
kubectl create namespace ckad-exam
```

---

## 問題 1: Pod の作成 (3 分)

**Namespace `ckad-exam` に以下の Pod を作成せよ:**

- 名前: `exam-pod`
- イメージ: `nginx:1.27`
- ラベル: `app=exam`, `tier=frontend`
- 環境変数: `APP_MODE=exam`
- ポート: 80

<details>
<summary>解答</summary>

```bash
kubectl run exam-pod --image=nginx:1.27 -n ckad-exam \
  --labels="app=exam,tier=frontend" \
  --port=80 --env="APP_MODE=exam"

# 確認
kubectl get pod exam-pod -n ckad-exam --show-labels
kubectl exec exam-pod -n ckad-exam -- env | grep APP_MODE
```
</details>

---

## 問題 2: マルチコンテナ Pod (5 分)

**Namespace `ckad-exam` に以下のマルチコンテナ Pod を作成せよ:**

- 名前: `multi-exam`
- コンテナ 1: `main` — イメージ `nginx:1.27`, ポート 80
- コンテナ 2: `sidecar` — イメージ `busybox:1.36`, コマンド `sh -c "while true; do wget -qO- localhost:80 > /dev/null; sleep 10; done"`

<details>
<summary>解答</summary>

```yaml
# multi-exam.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-exam
  namespace: ckad-exam
spec:
  containers:
  - name: main
    image: nginx:1.27
    ports:
    - containerPort: 80
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "while true; do wget -qO- localhost:80 > /dev/null; sleep 10; done"]
```

```bash
kubectl apply -f multi-exam.yaml
kubectl get pod multi-exam -n ckad-exam
kubectl logs multi-exam -n ckad-exam -c main --tail=3
```
</details>

---

## 問題 3: Job の作成 (4 分)

**以下の Job を作成せよ:**

- 名前: `exam-job`
- Namespace: `ckad-exam`
- イメージ: `busybox:1.36`
- コマンド: `echo "CKAD Exam Job Complete" && date`
- 完了数: 3, 並列数: 2
- backoffLimit: 4

<details>
<summary>解答</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: exam-job
  namespace: ckad-exam
spec:
  completions: 3
  parallelism: 2
  backoffLimit: 4
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "echo 'CKAD Exam Job Complete' && date"]
      restartPolicy: Never
```

```bash
kubectl apply -f exam-job.yaml
kubectl get jobs exam-job -n ckad-exam
kubectl logs -l job-name=exam-job -n ckad-exam
```
</details>

---

## 問題 4: CronJob の作成 (3 分)

**5 分ごとに実行される CronJob を作成せよ:**

- 名前: `exam-cron`
- Namespace: `ckad-exam`
- スケジュール: `*/5 * * * *`
- イメージ: `busybox:1.36`
- コマンド: `date && echo "Scheduled task executed"`

<details>
<summary>解答</summary>

```bash
kubectl create cronjob exam-cron --image=busybox:1.36 \
  --schedule="*/5 * * * *" -n ckad-exam \
  -- sh -c "date && echo 'Scheduled task executed'"

kubectl get cronjobs -n ckad-exam
```
</details>

---

## 問題 5: Deployment とローリングアップデート (6 分)

**以下の Deployment を作成し、アップデート後にロールバックせよ:**

1. 名前: `exam-deploy`, Namespace: `ckad-exam`
2. イメージ: `nginx:1.27`, レプリカ: 3
3. イメージを `nginx:1.28` に更新
4. ロールアウト状態を確認し、`nginx:1.27` にロールバック

<details>
<summary>解答</summary>

```bash
# 1. 作成
kubectl create deployment exam-deploy --image=nginx:1.27 --replicas=3 -n ckad-exam

# 2. 確認
kubectl get deployment exam-deploy -n ckad-exam

# 3. アップデート
kubectl set image deployment/exam-deploy nginx=nginx:1.28 -n ckad-exam
kubectl rollout status deployment/exam-deploy -n ckad-exam

# 4. ロールバック
kubectl rollout undo deployment/exam-deploy -n ckad-exam
kubectl rollout status deployment/exam-deploy -n ckad-exam
kubectl get deployment exam-deploy -n ckad-exam -o jsonpath='{.spec.template.spec.containers[0].image}'
# → nginx:1.27
```
</details>

---

## 問題 6: ConfigMap と Secret の使用 (6 分)

**ConfigMap と Secret を作成し、Pod で使用せよ:**

1. ConfigMap `exam-cm`: `DB_HOST=db.example.com`, `DB_PORT=5432`
2. Secret `exam-secret`: `DB_PASS=ExamPass123`
3. Pod `exam-config-pod` で上記を環境変数として注入

<details>
<summary>解答</summary>

```bash
kubectl create configmap exam-cm \
  --from-literal=DB_HOST=db.example.com \
  --from-literal=DB_PORT=5432 -n ckad-exam

kubectl create secret generic exam-secret \
  --from-literal=DB_PASS=ExamPass123 -n ckad-exam
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exam-config-pod
  namespace: ckad-exam
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "env | grep DB_ && sleep 3600"]
    envFrom:
    - configMapRef:
        name: exam-cm
    env:
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: exam-secret
          key: DB_PASS
```

```bash
kubectl apply -f exam-config-pod.yaml
kubectl exec exam-config-pod -n ckad-exam -- env | grep DB_
```
</details>

---

## 問題 7: Resource Limits と Probes (6 分)

**以下の Pod を作成せよ:**

- 名前: `exam-probes`
- イメージ: `nginx:1.27`
- Resources: requests cpu=50m, memory=64Mi / limits cpu=100m, memory=128Mi
- readinessProbe: HTTP GET `/` ポート 80, 初期遅延 3 秒
- livenessProbe: HTTP GET `/` ポート 80, 初期遅延 5 秒

<details>
<summary>解答</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exam-probes
  namespace: ckad-exam
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
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 5
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
```

```bash
kubectl apply -f exam-probes.yaml
kubectl describe pod exam-probes -n ckad-exam | grep -A 5 "Liveness\|Readiness\|Limits\|Requests"
```
</details>

---

## 問題 8: Service 作成 (4 分)

**`exam-deploy` Deployment に対して以下の Service を作成せよ:**

1. ClusterIP Service: 名前 `exam-clusterip`, ポート 80
2. NodePort Service: 名前 `exam-nodeport`, ポート 80

<details>
<summary>解答</summary>

```bash
kubectl expose deployment exam-deploy --name=exam-clusterip \
  --port=80 --target-port=80 -n ckad-exam

kubectl expose deployment exam-deploy --name=exam-nodeport \
  --port=80 --target-port=80 --type=NodePort -n ckad-exam

kubectl get svc -n ckad-exam
```
</details>

---

## 問題 9: Ingress (5 分)

**パスベースのルーティングを設定せよ:**

- `/app` → `exam-clusterip` Service, ポート 80
- Ingress Class: `nginx`
- rewrite-target アノテーション付き

<details>
<summary>解答</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: exam-ingress
  namespace: ckad-exam
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app
        pathType: Prefix
        backend:
          service:
            name: exam-clusterip
            port:
              number: 80
```

```bash
kubectl apply -f exam-ingress.yaml
kubectl get ingress -n ckad-exam
```
</details>

---

## 問題 10: PVC (5 分)

**PVC を作成し Pod で使用せよ:**

1. PVC: 名前 `exam-pvc`, 1Gi, ReadWriteOnce, StorageClass `managed-csi`
2. Pod `exam-pvc-pod` が `/data` にマウントし、ファイルを作成

<details>
<summary>解答</summary>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: exam-pvc
  namespace: ckad-exam
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: managed-csi
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: exam-pvc-pod
  namespace: ckad-exam
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'PVC data' > /data/test.txt && cat /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: exam-pvc
```

```bash
kubectl apply -f exam-pvc.yaml
kubectl get pvc -n ckad-exam
kubectl exec exam-pvc-pod -n ckad-exam -- cat /data/test.txt
```
</details>

---

## 問題 11: SecurityContext (5 分)

**以下の条件で Pod を作成せよ:**

- 名前: `exam-secure`
- runAsUser: 1000, runAsNonRoot: true
- readOnlyRootFilesystem: true
- `/tmp` に emptyDir をマウント (書き込み可能にする)

<details>
<summary>解答</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exam-secure
  namespace: ckad-exam
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'secure write' > /tmp/test && cat /tmp/test && sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

```bash
kubectl apply -f exam-secure.yaml
kubectl exec exam-secure -n ckad-exam -- id
kubectl exec exam-secure -n ckad-exam -- cat /tmp/test
kubectl exec exam-secure -n ckad-exam -- touch /fail 2>&1 || echo "Read-only FS: correct!"
```
</details>

---

## 問題 12: RBAC (6 分)

**ServiceAccount `exam-sa` を作成し、Pod と Service の読み取り権限のみ付与せよ:**

1. ServiceAccount: `exam-sa`
2. Role: `exam-reader` — pods, services に get, list, watch
3. RoleBinding: `exam-reader-binding`

<details>
<summary>解答</summary>

```bash
kubectl create serviceaccount exam-sa -n ckad-exam

kubectl create role exam-reader \
  --verb=get,list,watch \
  --resource=pods,services \
  -n ckad-exam

kubectl create rolebinding exam-reader-binding \
  --role=exam-reader \
  --serviceaccount=ckad-exam:exam-sa \
  -n ckad-exam

# テスト
kubectl auth can-i get pods -n ckad-exam --as=system:serviceaccount:ckad-exam:exam-sa
# → yes
kubectl auth can-i create pods -n ckad-exam --as=system:serviceaccount:ckad-exam:exam-sa
# → no
```
</details>

---

## 問題 13: NetworkPolicy (6 分)

**`exam-pod` への Ingress を `app=exam` ラベルの Pod からのみ許可する NetworkPolicy を作成せよ。**

<details>
<summary>解答</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: exam-netpol
  namespace: ckad-exam
spec:
  podSelector:
    matchLabels:
      app: exam
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: exam
    ports:
    - protocol: TCP
      port: 80
```

```bash
kubectl apply -f exam-netpol.yaml
kubectl describe networkpolicy exam-netpol -n ckad-exam
```
</details>

---

## 問題 14: ログとデバッグ (5 分)

**以下の操作を行え:**

1. `exam-pod` の直近 20 行のログを取得
2. `multi-exam` の `sidecar` コンテナのログを取得
3. `exam-pod` のイメージ名を JSONPath で取得

<details>
<summary>解答</summary>

```bash
# 1
kubectl logs exam-pod -n ckad-exam --tail=20

# 2
kubectl logs multi-exam -n ckad-exam -c sidecar --tail=10

# 3
kubectl get pod exam-pod -n ckad-exam -o jsonpath='{.spec.containers[0].image}'
```
</details>

---

## 問題 15: Helm (5 分)

**以下の操作を行え:**

1. bitnami/nginx チャートを `exam-nginx` としてインストール (Namespace `ckad-exam`, replicas=2, service.type=ClusterIP)
2. リリースの状態を確認
3. アンインストール

<details>
<summary>解答</summary>

```bash
# 1
helm install exam-nginx bitnami/nginx \
  --namespace ckad-exam \
  --set replicaCount=2 \
  --set service.type=ClusterIP

# 2
helm list -n ckad-exam
helm status exam-nginx -n ckad-exam
kubectl get all -n ckad-exam -l app.kubernetes.io/instance=exam-nginx

# 3
helm uninstall exam-nginx -n ckad-exam
```
</details>

---

## クリーンアップ

```bash
kubectl delete namespace ckad-exam
```

---

## 採点基準

| 問題 | 配点 | テーマ |
|---|---|---|
| 1 | 5% | Pod 基本 |
| 2 | 7% | マルチコンテナ |
| 3 | 7% | Job |
| 4 | 5% | CronJob |
| 5 | 8% | Deployment |
| 6 | 8% | ConfigMap/Secret |
| 7 | 8% | Resources/Probes |
| 8 | 6% | Service |
| 9 | 7% | Ingress |
| 10 | 7% | PVC |
| 11 | 7% | SecurityContext |
| 12 | 8% | RBAC |
| 13 | 7% | NetworkPolicy |
| 14 | 5% | Observability |
| 15 | 5% | Helm |
| **合計** | **100%** | |
