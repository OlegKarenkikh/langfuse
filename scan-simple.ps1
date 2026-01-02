# Simple CVE Scanner for Langfuse Containers
param(
    [string]$ContainerName
)

Write-Host "CVE Scanner for Langfuse Containers" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

if ($ContainerName) {
    Write-Host "Scanning $ContainerName for CVE vulnerabilities..." -ForegroundColor Yellow
    
    # Check package versions in container
    Write-Host "Checking key package versions:" -ForegroundColor Cyan
    
    # Check pnpm version
    $pnpmVersion = docker run --rm $ContainerName pnpm --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  pnpm: $pnpmVersion" -ForegroundColor White
        if ([version]$pnpmVersion -ge [version]"9.15.1") {
            Write-Host "    CVE-2024-47829 FIXED (pnpm >= 9.15.1)" -ForegroundColor Green
        } else {
            Write-Host "    CVE-2024-47829 VULNERABLE (pnpm < 9.15.1)" -ForegroundColor Red
        }
    }
    
    # Check Go version
    $goVersion = docker run --rm $ContainerName go version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Go: $goVersion" -ForegroundColor White
    }
    
    # Check Alpine version
    $alpineVersion = docker run --rm $ContainerName cat /etc/alpine-release 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Alpine version: $alpineVersion" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "CVE Scan Complete!" -ForegroundColor Green
} else {
    Write-Host "Usage: .\scan-simple.ps1 -ContainerName olegkarenkikh/langfuse:worker" -ForegroundColor Yellow
}