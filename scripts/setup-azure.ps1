# ============================================================
# Azure 環境セットアップスクリプト (PowerShell)
# ============================================================
# 使い方:
#   1. scripts/azure-env.sample → scripts/azure-env.ps1 にコピー
#   2. azure-env.ps1 の変数を PowerShell 形式に編集:
#        $SUBSCRIPTION_ID = "<your-subscription-id>"
#        $RESOURCE_GROUP  = "rg-aks-microservices"
#        $LOCATION        = "japaneast"
#        $ACR_NAME        = "<your-unique-acr-name>"
#        $AKS_CLUSTER     = "aks-microservices"
#   3. このスクリプトを実行:
#        .\scripts\setup-azure.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir "azure-env.ps1"

if (-not (Test-Path $EnvFile)) {
    Write-Host "❌ 環境変数ファイルが見つかりません: $EnvFile" -ForegroundColor Red
    Write-Host ""
    Write-Host "以下の手順で作成してください:" -ForegroundColor Yellow
    Write-Host "  1. scripts/azure-env.sample を scripts/azure-env.ps1 にコピー"
    Write-Host "  2. 以下の形式で編集:"
    Write-Host '     $SUBSCRIPTION_ID = "<your-subscription-id>"'
    Write-Host '     $RESOURCE_GROUP  = "rg-aks-microservices"'
    Write-Host '     $LOCATION        = "japaneast"'
    Write-Host '     $ACR_NAME        = "<your-unique-acr-name>"'
    Write-Host '     $AKS_CLUSTER     = "aks-microservices"'
    exit 1
}

# 環境変数を読み込み
. $EnvFile

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Azure 環境セットアップ" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  SUBSCRIPTION_ID : $SUBSCRIPTION_ID"
Write-Host "  RESOURCE_GROUP  : $RESOURCE_GROUP"
Write-Host "  LOCATION        : $LOCATION"
Write-Host "  ACR_NAME        : $ACR_NAME"
Write-Host "  AKS_CLUSTER     : $AKS_CLUSTER"
Write-Host ""

$confirm = Read-Host "この設定で続行しますか? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "中止しました。"
    exit 0
}

# --- Step 1: Azure CLI ログイン ---
Write-Host ""
Write-Host "📌 Step 1/5: Azure CLI ログイン..." -ForegroundColor Yellow
az login
az account set --subscription $SUBSCRIPTION_ID
Write-Host "✅ サブスクリプション設定完了" -ForegroundColor Green
az account show --output table

# --- Step 2: リソースグループ作成 ---
Write-Host ""
Write-Host "📌 Step 2/5: リソースグループ作成..." -ForegroundColor Yellow
az group create `
    --name $RESOURCE_GROUP `
    --location $LOCATION `
    --output table
Write-Host "✅ リソースグループ作成完了" -ForegroundColor Green

# --- Step 3: ACR 作成 ---
Write-Host ""
Write-Host "📌 Step 3/5: Azure Container Registry 作成..." -ForegroundColor Yellow
az acr create `
    --resource-group $RESOURCE_GROUP `
    --name $ACR_NAME `
    --sku Basic `
    --location $LOCATION `
    --output table

az acr login --name $ACR_NAME

$ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --query loginServer --output tsv
Write-Host "✅ ACR 作成完了: $ACR_LOGIN_SERVER" -ForegroundColor Green

# --- Step 4: AKS クラスター作成 ---
Write-Host ""
Write-Host "📌 Step 4/5: AKS クラスター作成 (数分かかります)..." -ForegroundColor Yellow
az aks create `
    --resource-group $RESOURCE_GROUP `
    --name $AKS_CLUSTER `
    --node-count 2 `
    --node-vm-size Standard_B2s `
    --generate-ssh-keys `
    --attach-acr $ACR_NAME `
    --location $LOCATION `
    --output table
Write-Host "✅ AKS クラスター作成完了" -ForegroundColor Green

# --- Step 5: kubectl 接続 ---
Write-Host ""
Write-Host "📌 Step 5/5: kubectl クレデンシャル取得..." -ForegroundColor Yellow
az aks get-credentials `
    --resource-group $RESOURCE_GROUP `
    --name $AKS_CLUSTER

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  ✅ セットアップ完了！" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  ACR Login Server : $ACR_LOGIN_SERVER"
Write-Host "  AKS Cluster      : $AKS_CLUSTER"
Write-Host ""
Write-Host "  確認コマンド:"
Write-Host "    kubectl get nodes"
Write-Host "    kubectl cluster-info"
Write-Host ""

kubectl get nodes
