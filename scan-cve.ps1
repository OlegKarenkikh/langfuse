# CVE Scanner for Langfuse Containers - Updated for 2025 CVEs
param(
    [string]$ContainerName,
    [switch]$All,
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

Write-Host "CVE Scanner for Langfuse Containers (2025 Update)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Target CVEs to check
$TargetCVEs = @{
    "CVE-2025-647567" = @{ Component = "npm/glob"; Version = "11.0.3"; Severity = "7.5"; Fixed = "^11.1.0" }
    "CVE-2025-608766" = @{ Component = "alpine/busybox"; Version = "1.37.0-r30"; Severity = "6.5"; Fixed = ">=1.37.0-r31" }
    "CVE-2024-478296" = @{ Component = "npm/pnpm"; Version = "9.15.1"; Severity = "6.5"; Fixed = ">=9.16.0" }
    "CVE-2025-641186" = @{ Component = "npm/tar"; Version = "7.5.1"; Severity = "6.1"; Fixed = "^7.5.2" }
    "CVE-2025-58891" = @{ Component = "npm/brace-expansion"; Version = "2.0.1"; Severity = "1.3"; Fixed = "^2.0.2" }
}

function Scan-Container {
    param([string]$ImageName)
    
    Write-Host "🔍 Scanning $ImageName for 2025 CVE vulnerabilities..." -ForegroundColor Yellow
    Write-Host "Target CVEs: CVE-2025-647567, CVE-2025-608766, CVE-2024-478296, CVE-2025-641186, CVE-2025-58891" -ForegroundColor Gray
    Write-Host ""
    
    $vulnerabilityCount = 0
    $fixedCount = 0
    
    # Check if Docker Scout is available
    $scoutAvailable = docker scout version 2>$null
    if ($LASTEXITCODE -eq 0 -and $Detailed) {
        Write-Host "Using Docker Scout for detailed CVE scanning..." -ForegroundColor Green
        docker scout cves $ImageName --format table --only-severity critical,high,medium
        Write-Host ""
    }
    
    Write-Host "🔍 Checking specific 2025 CVE targets:" -ForegroundColor Cyan
    
    # Check pnpm version (CVE-2024-478296)
    $pnpmVersion = docker run --rm $ImageName pnpm --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  📦 pnpm: $pnpmVersion" -ForegroundColor White
        if ([version]$pnpmVersion -ge [version]"9.16.0") {
            Write-Host "    ✅ CVE-2024-478296 FIXED (pnpm >= 9.16.0)" -ForegroundColor Green
            $fixedCount++
        } else {
            Write-Host "    ❌ CVE-2024-478296 VULNERABLE (pnpm $pnpmVersion < 9.16.0)" -ForegroundColor Red
            $vulnerabilityCount++
        }
    } else {
        Write-Host "  ⚠️  Could not check pnpm version" -ForegroundColor Yellow
    }
    
    # Check Alpine packages (CVE-2025-608766)
    Write-Host "  🐧 Checking Alpine packages..." -ForegroundColor White
    $alpineVersion = docker run --rm $ImageName cat /etc/alpine-release 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Alpine version: $alpineVersion" -ForegroundColor White
    }
    
    # Check busybox version (CVE-2025-608766)
    $busyboxVersion = docker run --rm $ImageName busybox 2>&1 | Select-String "BusyBox v" | Select-Object -First 1
    if ($busyboxVersion) {
        $versionMatch = $busyboxVersion -match "v(\d+\.\d+\.\d+)"
        if ($versionMatch) {
            $version = $matches[1]
            Write-Host "    📦 BusyBox: v$version" -ForegroundColor White
            # Note: Exact version comparison for busybox is complex due to Alpine packaging
            # We'll check if it's been updated recently
            $busyboxPackage = docker run --rm $ImageName apk info busybox 2>$null
            if ($busyboxPackage -match "1\.37\.0-r3[1-9]|1\.37\.[1-9]|1\.3[8-9]") {
                Write-Host "    ✅ CVE-2025-608766 LIKELY FIXED (busybox updated)" -ForegroundColor Green
                $fixedCount++
            } else {
                Write-Host "    ❌ CVE-2025-608766 POTENTIALLY VULNERABLE (busybox may need update)" -ForegroundColor Red
                $vulnerabilityCount++
            }
        }
    } else {
        Write-Host "    ⚠️  Could not determine busybox version" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "📊 CVE Status Summary:" -ForegroundColor Cyan
    Write-Host "  ✅ Fixed: $fixedCount" -ForegroundColor Green
    Write-Host "  ❌ Vulnerable: $vulnerabilityCount" -ForegroundColor Red
    Write-Host ""
    
    return @{ Fixed = $fixedCount; Vulnerable = $vulnerabilityCount }
}

function Check-PackageOverrides {
    param([string]$ImageName)
    
    Write-Host "📦 Checking package.json overrides for 2025 CVEs in $ImageName..." -ForegroundColor Yellow
    
    $overrideResults = @{ Fixed = 0; Missing = 0 }
    
    # Check if overrides are applied
    $packageJson = docker run --rm $ImageName cat package.json 2>$null
    if ($LASTEXITCODE -eq 0) {
        if ($packageJson -match '"overrides"') {
            Write-Host "  ✅ Package overrides section found" -ForegroundColor Green
            
            # Check specific CVE fixes
            if ($packageJson -match '"glob".*"(\^?11\.1\.0|1[2-9]\.|[2-9]\d\.)"') {
                Write-Host "    ✅ glob@^11.1.0+ (CVE-2025-647567 fixed)" -ForegroundColor Green
                $overrideResults.Fixed++
            } else {
                Write-Host "    ❌ glob version insufficient for CVE-2025-647567" -ForegroundColor Red
                $overrideResults.Missing++
            }
            
            if ($packageJson -match '"tar".*"(\^?7\.5\.[2-9]|7\.[6-9]\.|[8-9]\.)') {
                Write-Host "    ✅ tar@^7.5.2+ (CVE-2025-641186 fixed)" -ForegroundColor Green
                $overrideResults.Fixed++
            } else {
                Write-Host "    ❌ tar version insufficient for CVE-2025-641186" -ForegroundColor Red
                $overrideResults.Missing++
            }
            
            if ($packageJson -match '"brace-expansion".*"(\^?2\.0\.[2-9]|2\.[1-9]\.|[3-9]\.)') {
                Write-Host "    ✅ brace-expansion@^2.0.2+ (CVE-2025-58891 fixed)" -ForegroundColor Green
                $overrideResults.Fixed++
            } else {
                Write-Host "    ❌ brace-expansion version insufficient for CVE-2025-58891" -ForegroundColor Red
                $overrideResults.Missing++
            }
            
            # Legacy checks (may still be relevant)
            if ($packageJson -match '"cross-spawn".*"7\.0\.[6-9]|7\.[1-9]\.|[8-9]\."') {
                Write-Host "    ✅ cross-spawn@^7.0.6+ (legacy CVE fixed)" -ForegroundColor Green
            }
        } else {
            Write-Host "  ❌ No package overrides found - CVE fixes not applied!" -ForegroundColor Red
            $overrideResults.Missing += 3
        }
    } else {
        Write-Host "  ⚠️  Could not read package.json from container" -ForegroundColor Yellow
    }
    
    Write-Host ""
    return $overrideResults
}

if ($All) {
    $containers = @(
        "olegkarenkikh/langfuse:worker",
        "olegkarenkikh/langfuse:web",
        "olegkarenkikh/langfuse:worker-secure", 
        "olegkarenkikh/langfuse:web-secure"
    )
    
    $totalFixed = 0
    $totalVulnerable = 0
    
    foreach ($container in $containers) {
        $exists = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "^$container$"
        if ($exists) {
            Write-Host "=" * 60 -ForegroundColor Cyan
            Write-Host "Container: $container" -ForegroundColor Cyan
            Write-Host "=" * 60 -ForegroundColor Cyan
            
            $scanResult = Scan-Container $container
            $overrideResult = Check-PackageOverrides $container
            
            $totalFixed += $scanResult.Fixed + $overrideResult.Fixed
            $totalVulnerable += $scanResult.Vulnerable + $overrideResult.Missing
        } else {
            Write-Host "⚠️  Container $container not found locally" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "🎯 OVERALL CVE STATUS SUMMARY" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "✅ Total Fixed: $totalFixed" -ForegroundColor Green
    Write-Host "❌ Total Vulnerable: $totalVulnerable" -ForegroundColor Red
    
    if ($totalVulnerable -eq 0) {
        Write-Host "🛡️ ALL CVE VULNERABILITIES RESOLVED!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  $totalVulnerable vulnerabilities still need attention" -ForegroundColor Yellow
    }
    
} elseif ($ContainerName) {
    $scanResult = Scan-Container $ContainerName
    $overrideResult = Check-PackageOverrides $ContainerName
    
    $totalFixed = $scanResult.Fixed + $overrideResult.Fixed
    $totalVulnerable = $scanResult.Vulnerable + $overrideResult.Missing
    
    Write-Host "🎯 CONTAINER CVE STATUS" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host "✅ Fixed: $totalFixed" -ForegroundColor Green
    Write-Host "❌ Vulnerable: $totalVulnerable" -ForegroundColor Red
} else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\scan-cve.ps1 -ContainerName olegkarenkikh/langfuse:worker" -ForegroundColor White
    Write-Host "  .\scan-cve.ps1 -All" -ForegroundColor White
    Write-Host "  .\scan-cve.ps1 -All -Detailed  # Include Docker Scout scan" -ForegroundColor White
}

Write-Host "🛡️ CVE Scan Complete!" -ForegroundColor Green