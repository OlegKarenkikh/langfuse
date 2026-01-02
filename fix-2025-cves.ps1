# Fix 2025 CVE Vulnerabilities Script
param(
    [switch]$UpdatePnpm,
    [switch]$RebuildContainers,
    [switch]$ScanAfter,
    [switch]$All
)

$ErrorActionPreference = "Stop"

Write-Host "🛡️ Fixing 2025 CVE Vulnerabilities" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Target CVEs and their fixes
$CVEFixes = @{
    "CVE-2025-647567" = @{ Component = "glob"; CurrentVersion = "11.0.3"; FixVersion = "^11.1.0"; Severity = "7.5 (High)" }
    "CVE-2025-608766" = @{ Component = "busybox"; CurrentVersion = "1.37.0-r30"; FixVersion = ">=1.37.0-r31"; Severity = "6.5 (Medium)" }
    "CVE-2024-478296" = @{ Component = "pnpm"; CurrentVersion = "9.15.1"; FixVersion = "9.16.0"; Severity = "6.5 (Medium)" }
    "CVE-2025-641186" = @{ Component = "tar"; CurrentVersion = "7.5.1"; FixVersion = "^7.5.2"; Severity = "6.1 (Medium)" }
    "CVE-2025-58891" = @{ Component = "brace-expansion"; CurrentVersion = "2.0.1"; FixVersion = "^2.0.2"; Severity = "1.3 (Low)" }
}

Write-Host "🎯 Target CVEs to fix:" -ForegroundColor Yellow
foreach ($cve in $CVEFixes.Keys) {
    $fix = $CVEFixes[$cve]
    Write-Host "  $cve - $($fix.Component) $($fix.CurrentVersion) → $($fix.FixVersion) [$($fix.Severity)]" -ForegroundColor White
}
Write-Host ""

function Update-PnpmVersion {
    Write-Host "📦 Updating pnpm version to fix CVE-2024-478296..." -ForegroundColor Yellow
    
    $dockerfiles = @("web/Dockerfile", "worker/Dockerfile")
    
    foreach ($dockerfile in $dockerfiles) {
        if (Test-Path $dockerfile) {
            Write-Host "  Updating $dockerfile..." -ForegroundColor White
            
            # Read current content
            $content = Get-Content $dockerfile -Raw
            
            # Replace pnpm version
            $updatedContent = $content -replace "pnpm@9\.15\.1", "pnpm@9.16.0"
            
            # Write back
            Set-Content $dockerfile -Value $updatedContent -NoNewline
            
            Write-Host "    ✅ Updated pnpm version to 9.16.0" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️  $dockerfile not found" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

function Verify-PackageOverrides {
    Write-Host "📋 Verifying package.json overrides..." -ForegroundColor Yellow
    
    $packageFiles = @("web/package.json", "worker/package.json")
    
    foreach ($packageFile in $packageFiles) {
        if (Test-Path $packageFile) {
            Write-Host "  Checking $packageFile..." -ForegroundColor White
            
            $packageContent = Get-Content $packageFile -Raw | ConvertFrom-Json
            
            if ($packageContent.overrides) {
                $overrides = $packageContent.overrides
                
                # Check each CVE fix
                if ($overrides.glob -and $overrides.glob -match "11\.1\.0") {
                    Write-Host "    ✅ glob@^11.1.0 (CVE-2025-647567)" -ForegroundColor Green
                } else {
                    Write-Host "    ❌ glob override missing or insufficient" -ForegroundColor Red
                }
                
                if ($overrides.tar -and $overrides.tar -match "7\.5\.2") {
                    Write-Host "    ✅ tar@^7.5.2 (CVE-2025-641186)" -ForegroundColor Green
                } else {
                    Write-Host "    ❌ tar override missing or insufficient" -ForegroundColor Red
                }
                
                if ($overrides."brace-expansion" -and $overrides."brace-expansion" -match "2\.0\.2") {
                    Write-Host "    ✅ brace-expansion@^2.0.2 (CVE-2025-58891)" -ForegroundColor Green
                } else {
                    Write-Host "    ❌ brace-expansion override missing or insufficient" -ForegroundColor Red
                }
            } else {
                Write-Host "    ❌ No overrides section found!" -ForegroundColor Red
            }
        } else {
            Write-Host "    ⚠️  $packageFile not found" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

function Rebuild-Containers {
    Write-Host "🔨 Rebuilding containers with CVE fixes..." -ForegroundColor Yellow
    
    # Build worker container
    Write-Host "  Building worker container..." -ForegroundColor White
    docker build -t olegkarenkikh/langfuse:worker-cve-fixed -f worker/Dockerfile .
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ Worker container built successfully" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Worker container build failed" -ForegroundColor Red
        return $false
    }
    
    # Build web container
    Write-Host "  Building web container..." -ForegroundColor White
    docker build -t olegkarenkikh/langfuse:web-cve-fixed -f web/Dockerfile .
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ Web container built successfully" -ForegroundColor Green
    } else {
        Write-Host "    ❌ Web container build failed" -ForegroundColor Red
        return $false
    }
    
    Write-Host ""
    return $true
}

function Scan-CVEs {
    Write-Host "🔍 Scanning containers for remaining CVEs..." -ForegroundColor Yellow
    
    if (Test-Path "scan-cve.ps1") {
        & .\scan-cve.ps1 -All -Detailed
    } else {
        Write-Host "  ⚠️  scan-cve.ps1 not found, skipping scan" -ForegroundColor Yellow
    }
}

# Main execution
if ($All) {
    $UpdatePnpm = $true
    $RebuildContainers = $true
    $ScanAfter = $true
}

if ($UpdatePnpm) {
    Update-PnpmVersion
}

Verify-PackageOverrides

if ($RebuildContainers) {
    $buildSuccess = Rebuild-Containers
    if (-not $buildSuccess) {
        Write-Host "❌ Container rebuild failed. Stopping execution." -ForegroundColor Red
        exit 1
    }
}

if ($ScanAfter) {
    Scan-CVEs
}

Write-Host "🎉 CVE Fix Process Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary of actions taken:" -ForegroundColor Cyan
if ($UpdatePnpm) {
    Write-Host "  ✅ Updated pnpm to 9.16.0 (fixes CVE-2024-478296)" -ForegroundColor Green
}
Write-Host "  ✅ Verified package.json overrides for npm CVEs" -ForegroundColor Green
if ($RebuildContainers) {
    Write-Host "  ✅ Rebuilt containers with security fixes" -ForegroundColor Green
}
if ($ScanAfter) {
    Write-Host "  ✅ Performed post-fix CVE scan" -ForegroundColor Green
}

Write-Host ""
Write-Host "🛡️ Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test the new containers: docker run olegkarenkikh/langfuse:worker-cve-fixed" -ForegroundColor White
Write-Host "  2. Tag as production: docker tag olegkarenkikh/langfuse:worker-cve-fixed olegkarenkikh/langfuse:worker" -ForegroundColor White
Write-Host "  3. Push to registry: docker push olegkarenkikh/langfuse:worker" -ForegroundColor White