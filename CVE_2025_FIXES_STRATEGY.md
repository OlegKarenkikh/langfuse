# 🛡️ CVE 2025 Vulnerability Fixes Strategy

## 🚨 Identified CVE Vulnerabilities

| CVE ID | Component | Version | Severity | Priority |
|--------|-----------|---------|----------|----------|
| CVE-2025-647567 | npm/glob | 11.0.3 | 7.5 (High) | 🔴 Critical |
| CVE-2025-608766 | alpine/busybox | 1.37.0-r30 | 6.5 (Medium) | 🟡 High |
| CVE-2024-478296 | npm/pnpm | 9.15.1 | 6.5 (Medium) | 🟡 High |
| CVE-2025-641186 | npm/tar | 7.5.1 | 6.1 (Medium) | 🟡 Medium |
| CVE-2025-58891 | npm/brace-expansion | 2.0.1 | 1.3 (Low) | 🟢 Low |

## 🔧 Fix Strategy

### 1. NPM Package Vulnerabilities (Immediate)

#### Package.json Overrides
```json
{
  "overrides": {
    "glob": "^11.1.0",           // CVE-2025-647567 fix
    "tar": "^7.5.2",             // CVE-2025-641186 fix  
    "brace-expansion": "^2.0.2"  // CVE-2025-58891 fix
  }
}
```

#### PNPM Version Update
```dockerfile
# Update to latest stable pnpm version
RUN corepack enable && \
    corepack prepare pnpm@9.16.0 --activate
```

### 2. Alpine System Packages (Container Level)

#### Dockerfile Updates
```dockerfile
# Update Alpine base and busybox
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
    busybox>=1.37.0-r31 \
    libcrypto3 \
    libssl3 \
    libc6-compat
```

## 🚀 Implementation Plan

### Phase 1: Package Updates (Quick Win)
1. Update package.json overrides in both web and worker
2. Update pnpm version in Dockerfiles
3. Test builds locally

### Phase 2: System Updates (Container Rebuild)
1. Update Alpine packages in Dockerfiles
2. Rebuild containers with security patches
3. Scan for remaining vulnerabilities

### Phase 3: Verification
1. Run CVE scans on new containers
2. Verify all 5 CVEs are resolved
3. Tag and push secure images

## 📋 Action Items

- [ ] Update web/package.json with overrides
- [ ] Update worker/package.json with overrides  
- [ ] Update web/Dockerfile with pnpm@9.16.0
- [ ] Update worker/Dockerfile with pnpm@9.16.0
- [ ] Update Dockerfiles with Alpine security patches
- [ ] Rebuild containers
- [ ] Run CVE verification scans
- [ ] Tag and push secure images

## 🔍 Verification Commands

```powershell
# Scan all containers for CVEs
.\scan-cve.ps1 -All

# Verify specific fixes
docker run --rm olegkarenkikh/langfuse:web-secure pnpm --version
docker run --rm olegkarenkikh/langfuse:web-secure npm list glob tar brace-expansion
```

## 🎯 Expected Outcome

- **100% CVE resolution** (5/5 vulnerabilities fixed)
- **Secure container images** ready for production
- **Automated verification** of all fixes