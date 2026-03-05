#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Azure 環境セットアップスクリプト (Bash)
# ============================================================
# 使い方:
#   1. scripts/azure-env.sample → scripts/azure-env.sh にコピー
#   2. azure-env.sh の変数を自分の環境に合わせて編集
#   3. このスクリプトを実行:
#        chmod +x scripts/setup-azure.sh
#        ./scripts/setup-azure.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/azure-env.sh"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ 環境変数ファイルが見つかりません: $ENV_FILE"
    echo ""
    echo "以下のコマンドで作成してください:"
    echo "  cp scripts/azure-env.sample scripts/azure-env.sh"
    echo "  # azure-env.sh を編集して値を設定"
    exit 1
fi

# 環境変数を読み込み
source "$ENV_FILE"

echo "============================================"
echo "  Azure 環境セットアップ"
echo "============================================"
echo ""
echo "  SUBSCRIPTION_ID : ${SUBSCRIPTION_ID}"
echo "  RESOURCE_GROUP  : ${RESOURCE_GROUP}"
echo "  LOCATION        : ${LOCATION}"
echo "  ACR_NAME        : ${ACR_NAME}"
echo "  AKS_CLUSTER     : ${AKS_CLUSTER}"
echo ""

# --- 確認 ---
read -p "この設定で続行しますか? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "中止しました。"
    exit 0
fi

# --- Step 1: Azure CLI ログイン ---
echo ""
echo "📌 Step 1/5: Azure CLI ログイン..."
az login
az account set --subscription "${SUBSCRIPTION_ID}"
echo "✅ サブスクリプション設定完了"
az account show --output table

# --- Step 2: リソースグループ作成 ---
echo ""
echo "📌 Step 2/5: リソースグループ作成..."
az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --output table
echo "✅ リソースグループ作成完了"

# --- Step 3: ACR 作成 ---
echo ""
echo "📌 Step 3/5: Azure Container Registry 作成..."
az acr create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACR_NAME}" \
    --sku Basic \
    --location "${LOCATION}" \
    --output table

az acr login --name "${ACR_NAME}"

ACR_LOGIN_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer --output tsv)
echo "✅ ACR 作成完了: ${ACR_LOGIN_SERVER}"

# --- Step 4: AKS クラスター作成 ---
echo ""
echo "📌 Step 4/5: AKS クラスター作成 (数分かかります)..."
az aks create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER}" \
    --node-count 2 \
    --node-vm-size Standard_B2s \
    --generate-ssh-keys \
    --attach-acr "${ACR_NAME}" \
    --location "${LOCATION}" \
    --output table
echo "✅ AKS クラスター作成完了"

# --- Step 5: kubectl 接続 ---
echo ""
echo "📌 Step 5/5: kubectl クレデンシャル取得..."
az aks get-credentials \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AKS_CLUSTER}"

echo ""
echo "============================================"
echo "  ✅ セットアップ完了！"
echo "============================================"
echo ""
echo "  ACR Login Server : ${ACR_LOGIN_SERVER}"
echo "  AKS Cluster      : ${AKS_CLUSTER}"
echo ""
echo "  確認コマンド:"
echo "    kubectl get nodes"
echo "    kubectl cluster-info"
echo ""

kubectl get nodes
