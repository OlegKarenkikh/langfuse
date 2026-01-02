# Build Zero-CVE AlmaLinux Containers
param(
    [switch]$Worker,
    [switch]$Web,
    [switch]$All,
    [switch]$Push
)

$ErrorActionPreference = "Stop"

Write-Host "🛡️ Building Zero-CVE AlmaLinux Containers" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

$WorkerImage = "olegkarenkikh/langfuse:worker-zero-cve"
$WebImage = "olegkarenkikh/langfuse:web-zero-cve"

function Build-Container {
    param(
        [string]$Type,
        [string]$Dockerfile,
        [string]$ImageName
    )
    
    Write-Host "🔨 Building $Type container..." -ForegroundColor Yellow
    Write-Host "Dockerfile: $Dockerfile" -ForegroundColor Gray
    Write-Host "Image: $ImageName" -ForegroundColor Gray
    Write-Host ""
    
    $startTime = Get-Date
    
    try {
        docker build -f $Dockerfile -t $ImageName . --no-cache
        
        if ($LASTEXITCODE -eq 0) {
            $duration = (Get-Date) - $startTime
            Write-Host "✅ $Type container built successfully!" -ForegroundColor Green
            Write-Host "   Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
            Write-Host "   Image: $ImageName" -ForegroundColor Gray
            Write-Host ""
            
            # Scan for CVEs immediately
            Write-Host "🔍 Scanning $Type container for CVEs..." -ForegroundColor Cyan
            docker scout cves $ImageName --format packages --only-severity critical,high,medium
            Write-Host ""
            
            return $true
        } else {
            Write-Host "❌ $Type container build failed!" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Error building $Type container: $_" -ForegroundColor Red
        return $false
    }
}

$buildResults = @{}

if ($Worker -or $All) {
    $buildResults["Worker"] = Build-Container -Type "Worker" -Dockerfile "worker/Dockerfile.almalinux-zero-cve" -ImageName $WorkerImage
}

if ($Web -or $All) {
    $buildResults["Web"] = Build-Container -Type "Web" -Dockerfile "web/Dockerfile.almalinux-zero-cve" -ImageName $WebImage
}

if (-not ($Worker -or $Web -or $All)) {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\build-zero-cve.ps1 -Worker      # Build worker container" -ForegroundColor White
    Write-Host "  .\build-zero-cve.ps1 -Web         # Build web container" -ForegroundColor White
    Write-Host "  .\build-zero-cve.ps1 -All         # Build both containers" -ForegroundColor White
    Write-Host "  .\build-zero-cve.ps1 -All -Push   # Build and push to Docker Hub" -ForegroundColor White
    exit 0
}

# Summary
Write-Host "📊 Build Summary:" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan

$successCount = 0
$totalCount = 0

foreach ($result in $buildResults.GetEnumerator()) {
    $totalCount++
    if ($result.Value) {
        Write-Host "✅ $($result.Key): SUCCESS" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "❌ $($result.Key): FAILED" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Success Rate: $successCount/$totalCount" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })

# Push to Docker Hub if requested and all builds succeeded
if ($Push -and $successCount -eq $totalCount -and $totalCount -gt 0) {
    Write-Host ""
    Write-Host "🚀 Pushing containers to Docker Hub..." -ForegroundColor Blue
    
    if ($buildResults.ContainsKey("Worker") -and $buildResults["Worker"]) {
        Write-Host "Pushing worker container..." -ForegroundColor Yellow
        docker push $WorkerImage
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Worker container pushed successfully!" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to push worker container!" -ForegroundColor Red
        }
    }
    
    if ($buildResults.ContainsKey("Web") -and $buildResults["Web"]) {
        Write-Host "Pushing web container..." -ForegroundColor Yellow
        docker push $WebImage
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Web container pushed successfully!" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to push web container!" -ForegroundColor Red
        }
    }
}

Write-Host ""
if ($successCount -eq $totalCount -and $totalCount -gt 0) {
    Write-Host "🎉 All containers built successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔍 To verify CVE status:" -ForegroundColor Cyan
    if ($buildResults.ContainsKey("Worker")) {
        Write-Host "  docker scout cves $WorkerImage" -ForegroundColor White
    }
    if ($buildResults.ContainsKey("Web")) {
        Write-Host "  docker scout cves $WebImage" -ForegroundColor White
    }
} else {
    Write-Host "⚠️ Some builds failed. Check the logs above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🛡️ Zero-CVE Build Complete!" -ForegroundColor Green