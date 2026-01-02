# Build CVE-Free Debian Secure Worker
# Uses Debian Bookworm Slim + pnpm 10.x + forced glob/tar updates

$ErrorActionPreference = "Continue"
$IMAGE_NAME = "olegkarenkikh/langfuse"
$TAG = "worker-debian-secure"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building CVE-Free Worker (Debian Secure)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Strategy:" -ForegroundColor Yellow
Write-Host "  - Debian Bookworm Slim (no busybox CVE)" -ForegroundColor White
Write-Host "  - pnpm 10.x (fixes CVE-2024-47829)" -ForegroundColor White
Write-Host "  - glob@11.1.0 (fixes CVE-2025-64756)" -ForegroundColor White
Write-Host "  - tar@7.5.2 (fixes CVE-2025-64118)" -ForegroundColor White
Write-Host ""

# Build
Write-Host "Building image..." -ForegroundColor Yellow
docker build -f worker/Dockerfile.debian-secure -t "${IMAGE_NAME}:${TAG}" . 2>&1 | Tee-Object -FilePath "build_debian_secure.log"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host ""
    
    # Scan for CVEs
    Write-Host "Scanning for CVEs..." -ForegroundColor Yellow
    docker scout cves "${IMAGE_NAME}:${TAG}" --only-severity critical,high,medium 2>&1
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Build Complete: ${IMAGE_NAME}:${TAG}" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Build FAILED! Check build_debian_secure.log" -ForegroundColor Red
    exit 1
}
