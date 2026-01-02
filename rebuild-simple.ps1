# Simple CVE Fix Rebuild Script
Write-Host "🛡️ REBUILDING WITH CVE FIXES" -ForegroundColor Red
Write-Host "============================" -ForegroundColor Red
Write-Host ""

# Clean old images
Write-Host "🧹 Cleaning old images..." -ForegroundColor Yellow
docker rmi -f olegkarenkikh/langfuse:worker-cve-fixed 2>$null
docker rmi -f olegkarenkikh/langfuse:web-cve-fixed 2>$null
Write-Host ""

# Build worker
Write-Host "🔨 Building worker (NO CACHE)..." -ForegroundColor Yellow
docker build --no-cache -f worker/Dockerfile -t olegkarenkikh/langfuse:worker-cve-fixed .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Worker build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Worker built successfully" -ForegroundColor Green
Write-Host ""

# Build web  
Write-Host "🔨 Building web (NO CACHE)..." -ForegroundColor Yellow
docker build --no-cache -f web/Dockerfile -t olegkarenkikh/langfuse:web-cve-fixed .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Web build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Web built successfully" -ForegroundColor Green
Write-Host ""

# Verify versions
Write-Host "🔍 Verifying fixes..." -ForegroundColor Yellow
$workerPnpm = docker run --rm --entrypoint="" olegkarenkikh/langfuse:worker-cve-fixed pnpm --version
$webPnpm = docker run --rm --entrypoint="" olegkarenkikh/langfuse:web-cve-fixed pnpm --version

Write-Host "  Worker pnpm: $workerPnpm" -ForegroundColor White
Write-Host "  Web pnpm: $webPnpm" -ForegroundColor White
Write-Host ""

Write-Host "🎉 BUILD COMPLETE!" -ForegroundColor Green
Write-Host "Next: Run Docker Scout scan to verify CVE fixes" -ForegroundColor Yellow