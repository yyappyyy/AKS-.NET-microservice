# Step 13: GitOps と CI/CD

> **KCNA 配点: Cloud Native Architecture 16% + App Delivery 8%**

## 学習目標

- CI/CD の基本概念を理解する
- GitOps の 4 原則を理解する
- Push 型 vs Pull 型の違いを理解する
- ArgoCD と Flux の役割を理解する

---

## CI/CD

```
このリポジトリの例:
┌──────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────┐
│ Git Push │───▶│ dotnet test  │───▶│ docker build │───▶│ kubectl  │
│          │    │ dotnet build │    │ docker push  │    │ apply    │
└──────────┘    └──────────────┘    │  → ACR       │    │  → AKS   │
                     CI             └──────────────┘    └──────────┘
                                                             CD
```

| 用語 | 説明 |
|------|------|
| **CI** (Continuous Integration) | コードの自動ビルド・テスト |
| **CD** (Continuous Delivery) | ステージングへの自動デプロイ + 本番は手動承認 |
| **CD** (Continuous Deployment) | 本番まで完全自動 |

## GitOps の 4 原則

1. **宣言的** — YAML で望ましい状態を記述（`k8s/` ディレクトリ）
2. **バージョン管理** — Git で管理
3. **自動適用** — 承認された変更は自動でクラスターに反映
4. **継続的調整** — 実際の状態と Git の差分を検出・修復

### Push 型 vs Pull 型（試験頻出！）

```
Push 型（従来）:  CI Pipeline ──push──▶ K8s Cluster
                  ⚠️ CI にクラスター認証情報が必要

Pull 型（GitOps）: Git Repo ◀──watch── Agent(ArgoCD/Flux) ──reconcile──▶ K8s
                   ✅ 認証情報はクラスター内に閉じる
```

## ArgoCD vs Flux（両方 CNCF Graduated）

| | ArgoCD | Flux |
|--|--------|------|
| UI | **あり**（リッチ） | なし（デフォルト） |
| マルチクラスタ | ネイティブ対応 | 追加設定 |

---

## KCNA 試験チェックリスト

- [ ] GitOps の 4 原則（宣言的、Git管理、自動適用、継続的調整）
- [ ] **Pull 型** = GitOps（ArgoCD/Flux）
- [ ] ArgoCD, Flux = CNCF Graduated
- [ ] CI = ビルド・テスト、CD = デプロイ
