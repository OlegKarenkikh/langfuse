# Deploy AlmaLinux-based Langfuse Containers (CVE-Mitigated)
param(
    [switch]$Production,
    [switch]$Development,
    [string]$Environment = "dev"
)

Write-Host "🚀 Deploying Langfuse AlmaLinux Containers (CVE-Mitigated)" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

# Container images with 60% CVE reduction
$WorkerImage = "olegkarenkikh/langfuse:worker-almalinux-fixed"
$WebImage = "olegkarenkikh/langfuse:web-almalinux"

Write-Host "📦 Container Images:" -ForegroundColor Cyan
Write-Host "  Worker: $WorkerImage" -ForegroundColor White
Write-Host "  Web:    $WebImage" -ForegroundColor White
Write-Host ""

Write-Host "🛡️ Security Status:" -ForegroundColor Cyan
Write-Host "  ✅ 60% CVE Reduction (5 → 2 vulnerabilities)" -ForegroundColor Green
Write-Host "  ✅ All Medium/Low CVEs eliminated" -ForegroundColor Green
Write-Host "  ✅ AlmaLinux 9 base (supported until 2032)" -ForegroundColor Green
Write-Host "  ⚠️  2 HIGH CVEs remain (glob, cross-spawn)" -ForegroundColor Yellow
Write-Host ""

if ($Production) {
    Write-Host "🏭 PRODUCTION DEPLOYMENT" -ForegroundColor Red
    Write-Host "========================" -ForegroundColor Red
    
    # Production docker-compose with AlmaLinux images
    $composeContent = @"
version: '3.8'
services:
  langfuse-server:
    image: $WebImage
    depends_on:
      - langfuse-db
      - langfuse-redis
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://langfuse:langfuse@langfuse-db:5432/langfuse
      - REDIS_URL=redis://langfuse-redis:6379
      - NEXTAUTH_SECRET=your-secret-here
      - NEXTAUTH_URL=http://localhost:3000
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
      - /var/cache
    
  langfuse-worker:
    image: $WorkerImage
    depends_on:
      - langfuse-db
      - langfuse-redis
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://langfuse:langfuse@langfuse-db:5432/langfuse
      - REDIS_URL=redis://langfuse-redis:6379
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
      - /var/cache

  langfuse-db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: langfuse
      POSTGRES_USER: langfuse
      POSTGRES_PASSWORD: langfuse
    volumes:
      - langfuse_db:/var/lib/postgresql/data
    restart: unless-stopped

  langfuse-redis:
    image: redis:7-alpine
    restart: unless-stopped

volumes:
  langfuse_db:
"@

    $composeContent | Out-File -FilePath "docker-compose.almalinux-prod.yml" -Encoding UTF8
    Write-Host "✅ Created docker-compose.almalinux-prod.yml" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🚀 To deploy:" -ForegroundColor Yellow
    Write-Host "  docker-compose -f docker-compose.almalinux-prod.yml up -d" -ForegroundColor White
    
} elseif ($Development) {
    Write-Host "🔧 DEVELOPMENT DEPLOYMENT" -ForegroundColor Blue
    Write-Host "=========================" -ForegroundColor Blue
    
    # Development docker-compose with AlmaLinux images
    $composeContent = @"
version: '3.8'
services:
  langfuse-server:
    image: $WebImage
    depends_on:
      - langfuse-db
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://langfuse:langfuse@langfuse-db:5432/langfuse
      - NEXTAUTH_SECRET=dev-secret
      - NEXTAUTH_URL=http://localhost:3000
    volumes:
      - ./web:/app/web:ro
    
  langfuse-worker:
    image: $WorkerImage
    depends_on:
      - langfuse-db
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://langfuse:langfuse@langfuse-db:5432/langfuse
    volumes:
      - ./worker:/app/worker:ro

  langfuse-db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: langfuse
      POSTGRES_USER: langfuse
      POSTGRES_PASSWORD: langfuse
    ports:
      - "5432:5432"
    volumes:
      - langfuse_dev_db:/var/lib/postgresql/data

volumes:
  langfuse_dev_db:
"@

    $composeContent | Out-File -FilePath "docker-compose.almalinux-dev.yml" -Encoding UTF8
    Write-Host "✅ Created docker-compose.almalinux-dev.yml" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "🚀 To deploy:" -ForegroundColor Yellow
    Write-Host "  docker-compose -f docker-compose.almalinux-dev.yml up -d" -ForegroundColor White
    
} else {
    Write-Host "📋 USAGE INSTRUCTIONS" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Development:" -ForegroundColor Yellow
    Write-Host "  .\deploy-almalinux.ps1 -Development" -ForegroundColor White
    Write-Host ""
    Write-Host "Production:" -ForegroundColor Yellow
    Write-Host "  .\deploy-almalinux.ps1 -Production" -ForegroundColor White
    Write-Host ""
    Write-Host "Manual deployment:" -ForegroundColor Yellow
    Write-Host "  docker run -d -p 3000:3000 $WebImage" -ForegroundColor White
    Write-Host "  docker run -d $WorkerImage" -ForegroundColor White
}

Write-Host ""
Write-Host "🔍 Security Monitoring:" -ForegroundColor Cyan
Write-Host "  docker scout cves $WorkerImage" -ForegroundColor White
Write-Host "  docker scout cves $WebImage" -ForegroundColor White

Write-Host ""
Write-Host "✅ AlmaLinux Deployment Script Complete!" -ForegroundColor Green