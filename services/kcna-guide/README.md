# KCNA 学習ガイド — AKS ハンズオン対応

**Kubernetes and Cloud Native Associate (KCNA)** 試験の出題範囲に沿った学習ガイドです。
このリポジトリの **Product Catalog API** を題材に、実際に AKS 上で動かしながら学びます。

## KCNA 試験概要

| 項目 | 内容 |
|------|------|
| 試験時間 | 90 分 |
| 問題数 | 60 問（多肢選択式） |
| 合格ライン | 75% (45問以上) |
| 受験料 | $250 |
| 前提条件 | なし |
| 有効期限 | 3 年間 |

## 出題ドメインと配点

| ドメイン | 配点 | 対応ステップ |
|----------|------|-------------|
| Kubernetes Fundamentals | 46% | Step 03〜10 |
| Container Orchestration | 22% | Step 02, 05, 06 |
| Cloud Native Architecture | 16% | Step 01, 13 |
| Cloud Native Observability | 8% | Step 12 |
| Cloud Native Application Delivery | 8% | Step 11, 13 |

## 学習ステップ

| Step | テーマ | KCNA ドメイン |
|------|--------|--------------|
| [01](step-01-cloud-native-basics/) | Cloud Native の基礎 | Architecture |
| [02](step-02-container-basics/) | コンテナの基礎 | Orchestration |
| [03](step-03-k8s-architecture/) | Kubernetes アーキテクチャ | Fundamentals |
| [04](step-04-pods/) | Pod の基礎 | Fundamentals |
| [05](step-05-workloads/) | ワークロードリソース | Fundamentals, Orchestration |
| [06](step-06-services-networking/) | Service とネットワーキング | Fundamentals, Orchestration |
| [07](step-07-config-secrets/) | ConfigMap と Secret | Fundamentals |
| [08](step-08-storage/) | ストレージ | Fundamentals |
| [09](step-09-namespace-rbac/) | Namespace と RBAC | Fundamentals |
| [10](step-10-scheduling-scaling/) | スケジューリングとスケーリング | Fundamentals |
| [11](step-11-helm/) | Helm | App Delivery |
| [12](step-12-observability/) | Observability | Observability |
| [13](step-13-gitops-cicd/) | GitOps と CI/CD | Architecture, App Delivery |
| [14](step-14-security/) | セキュリティの基礎 | Fundamentals |
| [15](step-15-exam-prep/) | 模擬問題と総復習（丁寧な解説付き） | 全ドメイン |

## 前提環境

このガイドは **Azure Kubernetes Service (AKS)** を使います。

```bash
# 必要なツール
az version            # Azure CLI
kubectl version       # Kubernetes CLI
docker --version      # Docker

# AKS に接続（scripts/setup-azure.ps1 実行済みの場合）
kubectl get nodes
```

> Docker Desktop の Kubernetes でもほぼ同じ手順で学習可能です。

## 学習の進め方

1. **Step 01〜03** — 概念を理解する（座学中心）
2. **Step 04〜10** — kubectl を使って実際に手を動かす（ハンズオン中心）
3. **Step 11〜14** — エコシステムを学ぶ
4. **Step 15** — 模擬問題 30 問を解いて総復習（全問に丁寧な解説付き）
