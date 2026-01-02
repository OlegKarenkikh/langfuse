# Rebuild Secure Langfuse Containers with CVE Fixes
param(
    [switch]$Push,
    [switch]$Scan
)

$ErrorActionPreference = "Stop"

Write-Host "🛡️  Rebuilding Secure Langfuse Containers" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Define image tags
$WORKER_SECURE = "olegkarenkikh/langfuse:worker-secure"
$WEB_SECURE = "olegkarenkikh/langfuse:web-secure"
$WORKER_FINAL = "olegkarenkikh/langfuse:worker"
$WEB_FINAL = "olegkarenkikh/langfuse:web"

Write-Host "🔨 Building secure containers with CVE fixes..." -ForegroundColor Yellow
Write-Host ""

# Build worker container
Write-Host "Building worker container..." -ForegroundColor White
docker build --no-cache -f worker/Dockerfile -t $WORKER_SECURE .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Worker build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Worker container built successfully" -ForegroundColor Green

# Build web container  
Write-Host "Building web container..." -ForegroundColor White
docker build --no-cache -f web/Dockerfile -t $WEB_SECURE .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Web build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Web container built successfully" -ForegroundColor Green

Write-Host ""
Write-Host "🏷️  Tagging containers with final names..." -ForegroundColor Yellow

# Tag with final names
docker tag $WORKER_SECURE $WORKER_FINAL
docker tag $WEB_SECURE $WEB_FINAL

Write-Host "✅ Containers tagged successfully" -ForegroundColor Green
Write-Host ""

# Show built images
Write-Host "📦 Built images:" -ForegroundColor Cyan
docker images | Select-String "olegkarenkikh/langfuse"

if ($Scan) {
    Write-Host ""
    Write-Host "🔍 Running CVE scan on built containers..." -ForegroundColor Yellow
    .\scan-cve.ps1 -All
}

if ($Push) {
    Write-Host ""
    Write-Host "📤 Pushing containers to DockerHub..." -ForegroundColor Yellow
    
    # Push secure versions
    Write-Host "Pushing worker-secure..." -ForegroundColor White
    docker push $WORKER_SECURE
    
    Write-Host "Pushing web-secure..." -ForegroundColor White  
    docker push $WEB_SECURE
    
    # Push final versions
    Write-Host "Pushing worker..." -ForegroundColor White
    docker push $WORKER_FINAL
    
    Write-Host "Pushing web..." -ForegroundColor White
    docker push $WEB_FINAL
    
    Write-Host "✅ All containers pushed successfully!" -ForegroundColor Green
}

Write-Host ""
Write-Host "🛡️  CVE Fixes Applied:" -ForegroundColor Cyan
Write-Host "  ✅ pnpm@9.16.0 (CVE-2024-47829)" -ForegroundColor Green
Write-Host "  ✅ cross-spawn@^7.0.6 (CVE-2024-21538)" -ForegroundColor Green
Write-Host "  ✅ glob@^11.1.0 (CVE-2025-64756)" -ForegroundColor Green
Write-Host "  ✅ tar@^7.5.2 (CVE-2025-64118)" -ForegroundColor Green
Write-Host "  ✅ brace-expansion@^2.0.2 (CVE-2025-58891)" -ForegroundColor Green
Write-Host "  ✅ busybox>=1.37.0-r31 (CVE-2025-60876)" -ForegroundColor Green
Write-Host "  ✅ go>=1.25.6-r0 (CVE-2023-49292)" -ForegroundColor Green

Write-Host ""
Write-Host "🎉 Secure rebuild complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Yellow
Write-Host "  docker run -d olegkarenkikh/langfuse:worker" -ForegroundColor White
Write-Host "  docker run -d olegkarenkikh/langfuse:web" -ForegroundColor White