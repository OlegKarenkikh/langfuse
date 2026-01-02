# Build CVE-Free Distroless Images
$ErrorActionPreference = "Continue"
$REPO = "olegkarenkikh/langfuse"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building CVE-Free Distroless Images" -ForegroundColor Cyan
Write-Host "Base: gcr.io/distroless/nodejs22-debian12 (0 CVE)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Build Worker
Write-Host "`n[1/2] Building Worker..." -ForegroundColor Yellow
docker build --no-cache -f worker/Dockerfile.distroless -t "${REPO}:worker-distroless" . 2>&1 | Tee-Object -FilePath "build_worker_distroless.log"
$workerResult = $LASTEXITCODE

# Build Web
Write-Host "`n[2/2] Building Web..." -ForegroundColor Yellow
docker build --no-cache -f web/Dockerfile.distroless -t "${REPO}:web-distroless" . 2>&1 | Tee-Object -FilePath "build_web_distroless.log"
$webResult = $LASTEXITCODE

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build Results:" -ForegroundColor Cyan
if ($workerResult -eq 0) { Write-Host "  Worker: SUCCESS" -ForegroundColor Green } else { Write-Host "  Worker: FAILED" -ForegroundColor Red }
if ($webResult -eq 0) { Write-Host "  Web: SUCCESS" -ForegroundColor Green } else { Write-Host "  Web: FAILED" -ForegroundColor Red }

# Scan for CVEs
if ($workerResult -eq 0) {
    Write-Host "`nScanning Worker for CVEs..." -ForegroundColor Yellow
    docker scout cves "${REPO}:worker-distroless" --only-severity critical,high,medium 2>&1
}
if ($webResult -eq 0) {
    Write-Host "`nScanning Web for CVEs..." -ForegroundColor Yellow
    docker scout cves "${REPO}:web-distroless" --only-severity critical,high,medium 2>&1
}