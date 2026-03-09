# Step 03: Jobs と CronJobs

## 学習目標

- Job で 1 回限りのバッチ処理を実行できる
- `completions` / `parallelism` の違いを理解する
- CronJob で定期実行を設定できる
- 失敗時の `backoffLimit` / `activeDeadlineSeconds` を理解する

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-jobs
```

## 2. 基本的な Job

```bash
# kubectl create job でシンプルな Job を作成
kubectl create job hello-job --image=busybox:1.36 -n ckad-jobs \
  -- /bin/sh -c "echo 'Hello from Job!' && date && sleep 5 && echo 'Done!'"

# 状態確認
kubectl get jobs -n ckad-jobs
kubectl get pods -n ckad-jobs --watch   # Ctrl+C で終了

# 完了したら
kubectl get jobs -n ckad-jobs
kubectl logs job/hello-job -n ckad-jobs
```

## 3. YAML で Job を定義 (completions & parallelism)

```yaml
# parallel-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
  namespace: ckad-jobs
spec:
  completions: 6       # 合計 6 回成功させる
  parallelism: 3       # 同時に 3 つまで並列実行
  backoffLimit: 4      # 最大 4 回までリトライ
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          TASK_ID=$RANDOM
          echo "Worker $HOSTNAME starting task $TASK_ID"
          sleep $((RANDOM % 5 + 1))
          echo "Worker $HOSTNAME finished task $TASK_ID"
      restartPolicy: Never
```

```bash
kubectl apply -f parallel-job.yaml

# 並列実行を観察
kubectl get pods -n ckad-jobs -l job-name=parallel-job --watch

# 全ワーカーのログ
kubectl logs -n ckad-jobs -l job-name=parallel-job

# Job の詳細
kubectl describe job parallel-job -n ckad-jobs
```

## 4. 失敗する Job (backoffLimit テスト)

```yaml
# failing-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job
  namespace: ckad-jobs
spec:
  backoffLimit: 3
  activeDeadlineSeconds: 60
  template:
    spec:
      containers:
      - name: fail
        image: busybox:1.36
        command: ["sh", "-c", "echo 'About to fail...' && exit 1"]
      restartPolicy: Never
```

```bash
kubectl apply -f failing-job.yaml

# リトライの様子を確認 (Pod が複数作られる)
kubectl get pods -n ckad-jobs -l job-name=failing-job --watch

# 3 回リトライ後に失敗
kubectl describe job failing-job -n ckad-jobs
kubectl get jobs failing-job -n ckad-jobs -o jsonpath='{.status.conditions[0].type}'
```

## 5. CronJob — 定期実行

```bash
# kubectl create で CronJob 作成 (毎分実行)
kubectl create cronjob minute-log --image=busybox:1.36 \
  --schedule="*/1 * * * *" -n ckad-jobs \
  -- /bin/sh -c "echo '[$(date)] CronJob executed on $(hostname)'"

# 確認
kubectl get cronjobs -n ckad-jobs
kubectl get cronjobs -n ckad-jobs -o wide
```

## 6. YAML で CronJob を定義

```yaml
# report-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report-gen
  namespace: ckad-jobs
spec:
  schedule: "*/2 * * * *"       # 2 分ごと
  successfulJobsHistoryLimit: 3  # 成功した Job を 3 つ保持
  failedJobsHistoryLimit: 2      # 失敗した Job を 2 つ保持
  concurrencyPolicy: Forbid      # 前の Job が実行中なら次はスキップ
  startingDeadlineSeconds: 30
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: reporter
            image: busybox:1.36
            command: ["sh", "-c"]
            args:
            - |
              echo "=== Report Generation ==="
              echo "Time: $(date)"
              echo "Host: $(hostname)"
              echo "Uptime: $(cat /proc/uptime)"
              echo "=== Done ==="
          restartPolicy: OnFailure
```

```bash
kubectl apply -f report-cronjob.yaml

# CronJob の状態を確認
kubectl get cronjobs -n ckad-jobs

# 数分待って Job が生成されるか確認
kubectl get jobs -n ckad-jobs --watch

# 生成された Job のログ
kubectl get pods -n ckad-jobs -l job-name --sort-by=.metadata.creationTimestamp
kubectl logs -n ckad-jobs -l job-name=report-gen --prefix --tail=5
```

## 7. CronJob を手動トリガー

```bash
# CronJob から Job を手動で作成
kubectl create job manual-report --from=cronjob/report-gen -n ckad-jobs

# 結果確認
kubectl get jobs -n ckad-jobs
kubectl logs job/manual-report -n ckad-jobs
```

## 8. CronJob の一時停止・再開

```bash
# 一時停止
kubectl patch cronjob minute-log -n ckad-jobs -p '{"spec":{"suspend":true}}'
kubectl get cronjob minute-log -n ckad-jobs

# 再開
kubectl patch cronjob minute-log -n ckad-jobs -p '{"spec":{"suspend":false}}'
```

## 9. --dry-run で Job/CronJob の YAML 生成

```bash
# Job の YAML 生成
kubectl create job test-job --image=busybox:1.36 \
  --dry-run=client -o yaml -- echo "test"

# CronJob の YAML 生成
kubectl create cronjob test-cron --image=busybox:1.36 \
  --schedule="0 */6 * * *" --dry-run=client -o yaml \
  -- echo "every 6 hours"
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-jobs
```
