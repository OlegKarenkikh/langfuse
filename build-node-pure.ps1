# Build Pure Node.js Worker (No Go stdlib)
$ErrorActionPreference = "Continue"
$IMAGE = "olegkarenkikh/langfuse:worker-node-pure"

Write-Host "Building Pure Node.js Worker (No Go, No Corepack)" -ForegroundColor Cyan

docker build --no-cache -f worker/Dockerfile.node-pure -t $IMAGE . 2>&1 | Tee-Object -FilePath "build_node_pure.log"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild OK! Scanning CVEs..." -ForegroundColor Green
    docker scout cves $IMAGE --only-severity critical,high,medium 2>&1
} else {
    Write-Host "`nBuild FAILED!" -ForegroundColor Red
}
