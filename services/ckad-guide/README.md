# CKAD (Certified Kubernetes Application Developer) 学習ガイド

## 概要

このガイドは **CKAD 試験** に向けた実践的な学習ステップをまとめたものです。  
すべてのコマンドは **Azure Kubernetes Service (AKS)** で動作確認済みです。

## CKAD 試験の出題範囲 (2024)

| ドメイン | 割合 |
|---|---|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services & Networking | 20% |

## 学習ステップ一覧

| # | テーマ | ドメイン |
|---|---|---|
| [01](step01-pod-basics/README.md) | Pod の基本操作 | Design & Build |
| [02](step02-multi-container/README.md) | マルチコンテナ Pod | Design & Build |
| [03](step03-jobs-cronjobs/README.md) | Jobs と CronJobs | Design & Build |
| [04](step04-deployments/README.md) | Deployments とローリングアップデート | Deployment |
| [05](step05-configmap-secret/README.md) | ConfigMap と Secret | Configuration |
| [06](step06-resource-requests-limits/README.md) | Resource Requests / Limits と Probes | Configuration |
| [07](step07-services/README.md) | Service (ClusterIP / NodePort / LoadBalancer) | Services & Networking |
| [08](step08-ingress/README.md) | Ingress | Services & Networking |
| [09](step09-volumes/README.md) | Volumes と PersistentVolumeClaim | Configuration |
| [10](step10-security-context/README.md) | SecurityContext と ServiceAccount | Security |
| [11](step11-rbac/README.md) | RBAC (Role / RoleBinding) | Security |
| [12](step12-network-policy/README.md) | NetworkPolicy | Services & Networking |
| [13](step13-observability/README.md) | ログ・メトリクス・デバッグ | Observability |
| [14](step14-helm-kustomize/README.md) | Helm と Kustomize | Deployment |
| [15](step15-practice-exam/README.md) | 模擬試験 (15問) | 総合 |

## 前提条件

```bash
# AKS クラスターに接続
az aks get-credentials --resource-group rg-aks-microservices --name aks-microservices

# kubectl 動作確認
kubectl cluster-info
kubectl get nodes
```

## 学習のコツ

1. **コマンドを手で打つ** — コピペではなく自分で入力して覚える
2. **`--dry-run=client -o yaml`** を活用して YAML 生成を高速化
3. **各ステップの cleanup を必ず実行** してクラスターをクリーンに保つ
4. **`kubectl explain`** でフィールドの仕様を素早く確認する
5. **時間制限を意識** — CKAD は 2 時間 16 問、1 問平均 7.5 分
