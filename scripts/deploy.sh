#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AKS デプロイスクリプト (Bash)
# ============================================================
# 使い方:
#   ./scripts/deploy.sh [タグ名]
#   例: ./scripts/deploy.sh v2
#       ./scripts/deploy.sh        → latest タグを使用
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/azure-env.sh"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ 環境変数ファイルが見つかりません: $ENV_FILE"
    echo "  先に setup-azure.sh を実行してください。"
    exit 1
fi

source "$ENV_FILE"

TAG="${1:-latest}"
ACR_LOGIN_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer --output tsv)
IMAGE="${ACR_LOGIN_SERVER}/product-catalog:${TAG}"

echo "============================================"
echo "  AKS デプロイ"
echo "============================================"
echo "  Image: ${IMAGE}"
echo ""

# --- Docker ビルド & Push ---
echo "📌 Step 1/3: Docker イメージをビルド & Push..."
cd "${ROOT_DIR}/services/product-catalog"
docker build -t "${IMAGE}" .
az acr login --name "${ACR_NAME}"
docker push "${IMAGE}"
echo "✅ イメージ Push 完了"

# --- K8s マニフェスト適用 ---
echo ""
echo "📌 Step 2/3: K8s マニフェスト適用..."
cd "${ROOT_DIR}"

# deployment.yaml のイメージを置換して適用
sed "s|<ACR_LOGIN_SERVER>|${ACR_LOGIN_SERVER}|g" k8s/product-catalog/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/base/
kubectl apply -f k8s/product-catalog/service.yaml
kubectl apply -f k8s/product-catalog/hpa.yaml
kubectl apply -f k8s/product-catalog/configmap.yaml

# --- デプロイ確認 ---
echo ""
echo "📌 Step 3/3: デプロイ確認..."
kubectl rollout status deployment/product-catalog -n product-catalog --timeout=120s

echo ""
echo "============================================"
echo "  ✅ デプロイ完了！"
echo "============================================"
echo ""
echo "  確認手順:"
echo "    kubectl port-forward -n product-catalog svc/product-catalog 8080:80"
echo "    curl http://localhost:8080/healthz"
echo ""

kubectl get pods -n product-catalog
