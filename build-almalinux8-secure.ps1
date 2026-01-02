# Build CVE-Free AlmaLinux 8 Secure Worker
# Uses AlmaLinux 8 + Node.js binaries (no Go runtime) + pnpm 10.x

$ErrorActionPreference = "Continue"
$IMAGE_NAME = "olegkarenkikh/langfuse"
$TAG = "worker-almalinux8-secure"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building CVE-Free Worker (AlmaLinux 8)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Strategy:" -ForegroundColor Yellow
Write-Host "  - AlmaLinux 8 Minimal (no busybox CVE)" -ForegroundColor White
Write-Host "  - Node.js 22 from binaries (no Go runtime!)" -ForegroundColor White
Write-Host "  - pnpm 10.x (fixes CVE-2024-47829)" -ForegroundColor White
Write-Host "  - glob@11.1.0 (fixes CVE-2025-64756)" -ForegroundColor White
Write-Host "  - tar@7.5.2 (fixes CVE-2025-64118)" -ForegroundColor White
Write-Host ""

# Build
Write-Host "Building image..." -ForegroundColor Yellow
docker build -f worker/Dockerfile.almalinux8-secure -t "${IMAGE_NAME}:${TAG}" . 2>&1 | Tee-Object -FilePath "build_almalinux8_secure.log"

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
    Write-Host "Build FAILED! Check build_almalinux8_secure.log" -ForegroundColor Red
    exit 1
}
