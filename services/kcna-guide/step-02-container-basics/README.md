# Step 02: コンテナの基礎

> **KCNA 配点: Container Orchestration — 22%**

## 学習目標

- コンテナと VM の違いを説明できる
- OCI (Open Container Initiative) の仕様を理解する
- Dockerfile を読んで理解できる
- コンテナイメージのレイヤー構造を理解する

---

## コンテナ vs VM

```
VM                                    コンテナ
┌─────────┐ ┌─────────┐             ┌─────────┐ ┌─────────┐
│  App A  │ │  App B  │             │  App A  │ │  App B  │
├─────────┤ ├─────────┤             ├─────────┤ ├─────────┤
│ Guest OS│ │ Guest OS│             │ Bins/   │ │ Bins/   │
│ (数GB)  │ │ (数GB)  │             │ Libs    │ │ Libs    │
├─────────┴─┴─────────┤             ├─────────┴─┴─────────┤
│     Hypervisor      │             │  Container Runtime   │
├─────────────────────┤             ├──────────────────────┤
│      Host OS        │             │      Host OS         │
└─────────────────────┘             └──────────────────────┘
  各VMにOS → 重い                     カーネル共有 → 軽量
```

| 比較項目 | VM | コンテナ |
|----------|-----|---------|
| 起動時間 | 分単位 | 秒単位 |
| サイズ | GB 単位 | MB 単位 |
| 分離レベル | 強い（OS レベル） | プロセスレベル |
| リソース効率 | 低い | 高い |

---

## OCI (Open Container Initiative)

コンテナの標準仕様を策定する組織（試験に出る！）:

| 仕様 | 内容 |
|------|------|
| **Runtime Spec** | コンテナをどう実行するか |
| **Image Spec** | イメージのフォーマット |
| **Distribution Spec** | イメージの配布方法 |

### コンテナランタイムの階層

```
┌─────────────────────────────────┐
│  Container Engine (Docker等)     │  ← ユーザー向けツール
├─────────────────────────────────┤
│  High-level Runtime              │  ← CRI 実装
│  (containerd / CRI-O)           │
├─────────────────────────────────┤
│  Low-level Runtime (runc)        │  ← OCI Runtime Spec 実装
└─────────────────────────────────┘
```

| ランタイム | 種別 | CNCF | 特徴 |
|-----------|------|------|------|
| **containerd** | High-level | Graduated | Docker が使用、**AKS のデフォルト** |
| **CRI-O** | High-level | Incubating | Kubernetes 専用、軽量 |
| **runc** | Low-level | — | OCI 準拠の参照実装 |

---

## Dockerfile — このプロジェクトの実例

`services/product-catalog/Dockerfile`:

```dockerfile
# ===== ビルドステージ =====
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build    # SDK イメージ(大きい)
WORKDIR /app

COPY ProductCatalog.slnx ./
COPY src/ProductCatalog.Api/ProductCatalog.Api.csproj src/ProductCatalog.Api/
RUN dotnet restore src/ProductCatalog.Api/ProductCatalog.Api.csproj

COPY src/ src/
RUN dotnet publish src/ProductCatalog.Api/ProductCatalog.Api.csproj \
    -c Release -o /app/publish

# ===== ランタイムステージ =====
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime  # ランタイムのみ(小さい)
WORKDIR /app
USER $APP_UID                                          # non-root で実行

COPY --from=build /app/publish .                       # ビルド成果物だけコピー

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "ProductCatalog.Api.dll"]
```

**マルチステージビルドのメリット:**
- SDK (大きい) はビルド時のみ使用
- 最終イメージはランタイムだけ → **軽量 & セキュア**

---

## AKS ハンズオン: Docker イメージをビルドして ACR に Push

### 1. Docker イメージのビルド

```bash
# リポジトリのルートに移動（product-catalog の Dockerfile がある場所）
cd services/product-catalog

# Docker イメージをビルド
#   -t : イメージに名前（タグ）を付ける
#   .  : 現在ディレクトリの Dockerfile を使用
docker build -t product-catalog:local .

# ビルドしたイメージを確認
docker images | grep product-catalog

# レイヤー構造を確認（各命令がどのレイヤーになっているか学習用）
docker history product-catalog:local
```

### 2. ローカルでコンテナを起動してテスト

```bash
# コンテナをバックグラウンドで起動
#   -d      : デタッチモード（バックグラウンド）
#   -p 8080:8080 : ホストの8080番をコンテナの8080番にマッピング
#   --name  : コンテナに名前を付ける
docker run -d -p 8080:8080 --name catalog product-catalog:local

# 起動確認（STATUS が Up になっていれば OK）
docker ps | grep catalog

# ログを確認（.NET の起動ログが表示される）
docker logs catalog

# API にアクセスして動作確認
curl http://localhost:8080/healthz
curl http://localhost:8080/api/products

# コンテナの中に入る（デバッグ用）
docker exec -it catalog /bin/bash
# exit で抜ける
```

### 3. ACR に Push（AKS がある場合）

```bash
# 環境変数を設定（自分の ACR 名に置き換える）
ACR_NAME="<your-acr-name>"

# ACR にログイン
az acr login --name $ACR_NAME

# ACR のログインサーバー名を取得
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
echo "ACR: $ACR_LOGIN_SERVER"  # 例: yourname.azurecr.io

# イメージに ACR のタグを付け直す
docker tag product-catalog:local ${ACR_LOGIN_SERVER}/product-catalog:v1

# ACR に Push
docker push ${ACR_LOGIN_SERVER}/product-catalog:v1

# ACR 上のイメージを確認
az acr repository list --name $ACR_NAME --output table
az acr repository show-tags --name $ACR_NAME --repository product-catalog --output table
```

### 🧹 クリーンアップ

```bash
# コンテナを停止して削除
docker stop catalog
docker rm catalog

# ローカルイメージを削除（任意）
docker rmi product-catalog:local
# ACR タグ付きイメージも削除する場合
# docker rmi ${ACR_LOGIN_SERVER}/product-catalog:v1

# 全停止コンテナを一括削除（注意: 他のコンテナも消える）
# docker container prune -f
```

---

## KCNA 試験チェックリスト

- [ ] コンテナと VM の違い（カーネル共有、軽量、高速起動）
- [ ] OCI の 3 つの仕様（Runtime, Image, Distribution）
- [ ] containerd（CNCF Graduated）と CRI-O（Incubating）の違い
- [ ] Dockerfile の主要命令（FROM, COPY, RUN, EXPOSE, ENTRYPOINT）
- [ ] マルチステージビルドでイメージを軽量化する仕組み
