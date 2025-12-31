# Build script for docker-compose.custom.yml
# Usage: .\build-custom.ps1

Write-Host "Building Langfuse services from docker-compose.custom.yml..." -ForegroundColor Green

# Set build ID if not provided
if (-not $env:NEXT_PUBLIC_BUILD_ID) {
    $env:NEXT_PUBLIC_BUILD_ID = "local"
    Write-Host "Using default BUILD_ID: local" -ForegroundColor Yellow
}

# Build using docker compose
Write-Host "`nBuilding worker and web services..." -ForegroundColor Cyan
docker compose -f docker-compose.custom.yml build

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Check the error messages above for details." -ForegroundColor Yellow
    exit $LASTEXITCODE
}

