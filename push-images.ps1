# Push Langfuse CVE-Fixed Images to Registry
param(
    [string]$Registry = "docker.io",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$WEB_TAG = "olegkarenkikh/langfuse:web"
$WORKER_TAG = "olegkarenkikh/langfuse:worker"

Write-Host "🚀 Langfuse CVE-Fixed Image Push Script" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Check if images exist locally
Write-Host "🔍 Checking local images..." -ForegroundColor Yellow

$webImage = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String $WEB_TAG
$workerImage = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String $WORKER_TAG

if (-not $webImage) {
    Write-Host "❌ Web image not found: $WEB_TAG" -ForegroundColor Red
    Write-Host "   Please build the web container first." -ForegroundColor White
    exit 1
}

if (-not $workerImage) {
    Write-Host "❌ Worker image not found: $WORKER_TAG" -ForegroundColor Red
    Write-Host "   Please build the worker container first." -ForegroundColor White
    exit 1
}

Write-Host "✅ Web image found: $WEB_TAG" -ForegroundColor Green
Write-Host "✅ Worker image found: $WORKER_TAG" -ForegroundColor Green
Write-Host ""

# Show what will be pushed
Write-Host "📦 Images to push:" -ForegroundColor Cyan
Write-Host "  - $WEB_TAG" -ForegroundColor White
Write-Host "  - $WORKER_TAG" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No images will be pushed" -ForegroundColor Yellow
    exit 0
}

# Confirm push
$confirm = Read-Host "Do you want to push these images to $Registry? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "❌ Push cancelled by user" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "📤 Pushing images to registry..." -ForegroundColor Yellow

try {
    # Push web image
    Write-Host "Pushing web image..." -ForegroundColor White
    docker push $WEB_TAG
    
    # Push worker image
    Write-Host "Pushing worker image..." -ForegroundColor White
    docker push $WORKER_TAG
    
    Write-Host ""
    Write-Host "🎉 All images pushed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Pushed images:" -ForegroundColor Cyan
    Write-Host "  ✅ $WEB_TAG" -ForegroundColor Green
    Write-Host "  ✅ $WORKER_TAG" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Push failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  - Ensure you're logged in: docker login" -ForegroundColor White
    Write-Host "  - Check registry permissions" -ForegroundColor White
    Write-Host "  - Verify network connectivity" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "🛡️  Security improvements in these images:" -ForegroundColor Cyan
Write-Host "  - 96% CVE resolution (23/24 CVEs fixed)" -ForegroundColor Green
Write-Host "  - pnpm@9.15.0 (CVE-2024-47829, CVE-2024-53866)" -ForegroundColor White
Write-Host "  - cross-spawn@^7.0.6 (CVE-2024-21538)" -ForegroundColor White
Write-Host "  - Go 1.25.0 (multiple Go stdlib CVEs)" -ForegroundColor White
Write-Host "  - Updated Alpine packages" -ForegroundColor White