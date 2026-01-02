# Build Status Monitor for Langfuse Containers
param(
    [switch]$StartWorker,
    [switch]$Monitor
)

$WEB_TAG = "langfuse/langfuse-web:cve-fixed-$(Get-Date -Format 'yyyyMMdd')"
$WORKER_TAG = "langfuse/langfuse-worker:cve-fixed-$(Get-Date -Format 'yyyyMMdd')"

if ($Monitor) {
    Write-Host "🔍 Monitoring build progress..." -ForegroundColor Cyan
    
    # Check if web build is running
    $webProcess = Get-Process -Name "docker" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*web*" }
    if ($webProcess) {
        Write-Host "✅ Web container build is running (PID: $($webProcess.Id))" -ForegroundColor Green
    } else {
        Write-Host "❌ Web container build not detected" -ForegroundColor Red
    }
    
    # Show current Docker processes
    Write-Host "`n📊 Current Docker processes:" -ForegroundColor Yellow
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Show Docker images
    Write-Host "`n🏷️  Available Langfuse images:" -ForegroundColor Yellow
    docker images | Select-String "langfuse"
}

if ($StartWorker) {
    Write-Host "🔨 Starting worker container build..." -ForegroundColor Yellow
    Write-Host "Worker image tag: $WORKER_TAG" -ForegroundColor White
    
    # Start worker build in background
    Start-Process -FilePath "docker" -ArgumentList "build", "--no-cache", "-f", "worker/Dockerfile", "-t", $WORKER_TAG, "-t", "langfuse/langfuse-worker:latest", "." -NoNewWindow
    
    Write-Host "✅ Worker build started in background" -ForegroundColor Green
}

Write-Host "`n🛡️  CVE Fixes Applied:" -ForegroundColor Cyan
Write-Host "  - pnpm@9.15.0 (CVE-2024-47829, CVE-2024-53866)" -ForegroundColor White
Write-Host "  - cross-spawn@^7.0.6 (CVE-2024-21538)" -ForegroundColor White
Write-Host "  - Go 1.25.0 (multiple Go stdlib CVEs)" -ForegroundColor White
Write-Host "  - Updated Alpine packages" -ForegroundColor White