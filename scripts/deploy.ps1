# ============================================================
# AKS デプロイスクリプト (PowerShell)
# ============================================================
# 使い方:
#   .\scripts\deploy.ps1 [-Tag "v2"]
#   .\scripts\deploy.ps1              → latest タグを使用
# ============================================================

param(
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$EnvFile = Join-Path $ScriptDir "azure-env.ps1"

if (-not (Test-Path $EnvFile)) {
    Write-Host "❌ 環境変数ファイルが見つかりません: $EnvFile" -ForegroundColor Red
    Write-Host "  先に setup-azure.ps1 を実行してください。"
    exit 1
}

. $EnvFile

$ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --query loginServer --output tsv
$Image = "${ACR_LOGIN_SERVER}/product-catalog:${Tag}"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AKS デプロイ" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Image: $Image"
Write-Host ""

# --- Docker ビルド & Push ---
Write-Host "📌 Step 1/3: Docker イメージをビルド & Push..." -ForegroundColor Yellow
Push-Location (Join-Path $RootDir "services\product-catalog")
docker build -t $Image .
az acr login --name $ACR_NAME
docker push $Image
Pop-Location
Write-Host "✅ イメージ Push 完了" -ForegroundColor Green

# --- K8s マニフェスト適用 ---
Write-Host ""
Write-Host "📌 Step 2/3: K8s マニフェスト適用..." -ForegroundColor Yellow
Push-Location $RootDir

$deployYaml = (Get-Content k8s\product-catalog\deployment.yaml -Raw) -replace "<ACR_LOGIN_SERVER>", $ACR_LOGIN_SERVER
$deployYaml | kubectl apply -f -
kubectl apply -f k8s\base\
kubectl apply -f k8s\product-catalog\service.yaml
kubectl apply -f k8s\product-catalog\hpa.yaml
kubectl apply -f k8s\product-catalog\configmap.yaml
Pop-Location

# --- デプロイ確認 ---
Write-Host ""
Write-Host "📌 Step 3/3: デプロイ確認..." -ForegroundColor Yellow
kubectl rollout status deployment/product-catalog -n product-catalog --timeout=120s

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  ✅ デプロイ完了！" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  確認手順:"
Write-Host "    kubectl port-forward -n product-catalog svc/product-catalog 8080:80"
Write-Host "    curl http://localhost:8080/healthz"
Write-Host ""

kubectl get pods -n product-catalog
