# CKA 学習ガイド — AKS ハンズオン対応

**Certified Kubernetes Administrator (CKA)** 試験の出題範囲に沿った実践的な学習ガイドです。
このリポジトリの **Product Catalog API** と AKS を使い、実際にコマンドを叩きながら学びます。

> **CKA は実技試験です。** 暗記ではなく「kubectl を使って問題を解決する力」が問われます。

## CKA 試験概要

| 項目 | 内容 |
|------|------|
| 試験時間 | **120 分** |
| 形式 | **パフォーマンスベース（実技）** — ターミナルで kubectl を操作 |
| 問題数 | 15〜20 問 |
| 合格ライン | **66%** |
| 受験料 | $395（1 回リテイク付き） |
| 前提条件 | なし（KCNA があると楽） |
| 有効期限 | 2 年間 |
| 環境 | ブラウザ上のターミナル、kubernetes.io のドキュメント参照可能 |

## 出題ドメインと配点

| ドメイン | 配点 | 対応ステップ |
|----------|------|-------------|
| **Troubleshooting** | **30%** | Step 11, 12, 13 |
| Cluster Architecture, Installation & Configuration | **25%** | Step 01, 02, 03, 04 |
| Services & Networking | **20%** | Step 07, 08 |
| Workloads & Scheduling | **15%** | Step 05, 06 |
| Storage | **10%** | Step 09, 10 |

## 学習ステップ

| Step | テーマ | CKA ドメイン | 配点 |
|------|--------|-------------|------|
| [01](step-01-cluster-architecture/) | クラスターアーキテクチャ詳細 | Architecture | 25% |
| [02](step-02-kubeadm-cluster-setup/) | kubeadm とクラスター構築 | Architecture | 25% |
| [03](step-03-rbac-security/) | RBAC とセキュリティ | Architecture | 25% |
| [04](step-04-etcd-backup-restore/) | etcd バックアップとリストア | Architecture | 25% |
| [05](step-05-workloads-scheduling/) | ワークロード管理 | Workloads | 15% |
| [06](step-06-advanced-scheduling/) | 高度なスケジューリング | Workloads | 15% |
| [07](step-07-services-networking/) | Service とネットワーキング | Networking | 20% |
| [08](step-08-ingress-dns/) | Ingress と CoreDNS | Networking | 20% |
| [09](step-09-storage/) | ストレージ（PV/PVC/SC） | Storage | 10% |
| [10](step-10-configmap-secret-advanced/) | ConfigMap & Secret 応用 | Storage | 10% |
| [11](step-11-troubleshooting-nodes/) | Node のトラブルシューティング | Troubleshooting | 30% |
| [12](step-12-troubleshooting-pods/) | Pod のトラブルシューティング | Troubleshooting | 30% |
| [13](step-13-logging-monitoring/) | ロギングとモニタリング | Troubleshooting | 30% |
| [14](step-14-cluster-maintenance/) | クラスターメンテナンス | Architecture | 25% |
| [15](step-15-practice-exam/) | 模擬問題（実技形式） | 全ドメイン | — |

## CKA vs KCNA の違い

| | KCNA | CKA |
|--|------|-----|
| 形式 | 多肢選択式 | **実技（ターミナル操作）** |
| レベル | 入門 | **管理者レベル** |
| 時間 | 90 分 | **120 分** |
| 合格 | 75% | **66%** |
| ドキュメント | 参照不可 | **kubernetes.io 参照可** |

## 試験テクニック

### 試験中に使える時短テクニック

```bash
# エイリアス設定（試験開始直後に設定）
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'

# bash 補完を有効化
source <(kubectl completion bash)
complete -o default -F __start_kubectl k

# デフォルト Namespace の切替（問題ごとに指定される）
kubectl config set-context --current --namespace=<namespace>

# ドライラン + YAML 生成（マニフェスト作成の雛形）
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create deployment web --image=nginx --dry-run=client -o yaml > deploy.yaml
kubectl expose deployment web --port=80 --dry-run=client -o yaml > svc.yaml
```

### 試験中に参照できるドキュメント

- https://kubernetes.io/docs/
- https://kubernetes.io/blog/

> kubectl のチートシートは特に有用:
> https://kubernetes.io/docs/reference/kubectl/cheatsheet/

## 前提環境

```bash
# AKS クラスターに接続済みであること
kubectl cluster-info
kubectl get nodes
```
