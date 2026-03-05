# Step 14: セキュリティの基礎

> **KCNA 配点: Kubernetes Fundamentals — 46%**

## 学習目標

- 4C のセキュリティレイヤーを理解する
- NetworkPolicy でネットワーク制御を理解する
- SecurityContext を理解する
- Supply Chain Security の基本を知る

---

## 4C モデル

```
┌─────────────────────────────────┐
│           Cloud                 │  Azure、IAM、NSG
│  ┌───────────────────────────┐  │
│  │       Cluster             │  │  RBAC、NetworkPolicy、Admission
│  │  ┌─────────────────────┐  │  │
│  │  │    Container        │  │  │  SecurityContext、イメージスキャン
│  │  │  ┌───────────────┐  │  │  │
│  │  │  │    Code       │  │  │  │  脆弱性スキャン、依存関係
│  │  │  └───────────────┘  │  │  │
│  │  └─────────────────────┘  │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

## 実プロジェクトの SecurityContext

`k8s/product-catalog/deployment.yaml` より:

```yaml
securityContext:
  allowPrivilegeEscalation: false  # 特権昇格を禁止
  readOnlyRootFilesystem: false    # ルートFS
  runAsNonRoot: true               # root での実行を禁止
  runAsUser: 1654                  # 特定ユーザーで実行
```

## NetworkPolicy

> **デフォルトでは全通信が許可されている。** NetworkPolicy を適用して制限する。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-only
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - port: 8080
```

## Policy Engines

| ツール | CNCF | 特徴 |
|--------|------|------|
| **OPA/Gatekeeper** | Graduated | Rego 言語でポリシー記述 |
| **Kyverno** | Incubating | YAML でポリシー記述 |

## Supply Chain Security

| 概念 | 説明 |
|------|------|
| イメージスキャン | 脆弱性を検出 (Trivy, Microsoft Defender) |
| イメージ署名 | 改ざん防止 (Cosign, Notary) |
| SBOM | ソフトウェア部品表 |
| Distroless | 不要なツールを排除した最小イメージ |

---

## KCNA 試験チェックリスト

- [ ] 4C モデル（Cloud → Cluster → Container → Code）
- [ ] **NetworkPolicy のデフォルト = 全許可**
- [ ] runAsNonRoot, readOnlyRootFilesystem の意味
- [ ] OPA/Gatekeeper (CNCF Graduated) = ポリシーエンジン
- [ ] Supply Chain Security の基本概念
