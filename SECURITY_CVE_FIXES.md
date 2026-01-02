# Security CVE Fixes Applied

This document tracks the CVE vulnerabilities that have been addressed in this project.

## Fixed CVEs

### High Severity (7.0+)

#### CVE-2024-21538 (7.7H) - cross-spawn
- **Package**: npm/cross-spawn/7.0.3
- **Fix**: Updated to cross-spawn@^7.0.6
- **Location**: package.json overrides and pnpm.overrides

#### CVE-2025-64756 (7.5H) - glob  
- **Package**: npm/glob/11.0.3
- **Fix**: Already updated to glob@^11.1.0
- **Location**: package.json overrides and pnpm.overrides

#### Go stdlib CVEs (7.5H) - Multiple
- **CVE-2025-58187, CVE-2025-61729, CVE-2025-61725, CVE-2025-61723, CVE-2025-58188**
- **Package**: golang/stdlib/1.24.6
- **Fix**: Updated Go to 1.25.0 in .devcontainer/Dockerfile
- **Location**: .devcontainer/Dockerfile

#### CVE-2025-47913 (7.5H) - golang.org/x/crypto
- **Package**: golang/golang.org/x/crypto/0.36.0
- **Fix**: Updated golang-migrate to v4.20.0 (includes updated crypto)
- **Location**: web/Dockerfile, .devcontainer/Dockerfile

### Medium Severity (6.0-6.9)

#### CVE-2024-47829 (6.5M) - pnpm
- **Package**: npm/pnpm/9.5.0
- **Fix**: Updated to pnpm@9.15.0
- **Locations**: 
  - package.json packageManager
  - web/Dockerfile
  - worker/Dockerfile  
  - .devcontainer/Dockerfile

#### CVE-2025-60876 (6.5M) - busybox
- **Package**: apk/alpine/busybox/1.37.0-r30
- **Fix**: Updated Alpine packages to latest available
- **Locations**:
  - web/Dockerfile
  - worker/Dockerfile

#### CVE-2025-64118 (6.1M) - tar
- **Package**: npm/tar/7.5.1
- **Fix**: Already updated to tar@^7.5.2
- **Location**: package.json overrides and pnpm.overrides

#### CVE-2024-53866 (5.8M) - pnpm
- **Package**: npm/pnpm/9.5.0
- **Fix**: Updated to pnpm@9.15.0 (same as CVE-2024-47829)

#### CVE-2025-61727 (6.5M) - golang stdlib
- **Package**: golang/stdlib/1.24.6
- **Fix**: Updated Go to 1.25.0
- **Location**: .devcontainer/Dockerfile

### Medium-Low Severity (5.0-5.9)

#### Multiple Go stdlib CVEs (5.3M)
- **CVE-2025-58189, CVE-2025-47912, CVE-2025-61724, CVE-2025-58186, CVE-2025-58185**
- **Package**: golang/stdlib/1.24.6
- **Fix**: Updated Go to 1.25.0
- **Location**: .devcontainer/Dockerfile

#### CVE-2025-47914, CVE-2025-58181 (5.3M) - golang.org/x/crypto
- **Package**: golang/golang.org/x/crypto/0.36.0
- **Fix**: Updated golang-migrate to v4.20.0
- **Location**: web/Dockerfile, .devcontainer/Dockerfile

#### CVE-2020-8911 (5.6M) - AWS SDK
- **Package**: golang/github.com/aws/aws-sdk-go/1.49.6
- **Fix**: Updated through golang-migrate v4.20.0
- **Location**: Indirect dependency

### Low Severity (1.0-4.9)

#### CVE-2025-58183 (4.3M) - golang stdlib
- **Package**: golang/stdlib/1.24.6
- **Fix**: Updated Go to 1.25.0
- **Location**: .devcontainer/Dockerfile

#### CVE-2020-8912 (2.5L) - AWS SDK
- **Package**: golang/github.com/aws/aws-sdk-go/1.49.6
- **Fix**: Updated through golang-migrate v4.20.0
- **Location**: Indirect dependency

#### CVE-2025-5889 (1.3L) - brace-expansion
- **Package**: npm/brace-expansion/2.0.1
- **Fix**: Already updated to brace-expansion@^2.0.2
- **Location**: package.json overrides and pnpm.overrides

## Verification

To verify these fixes are applied:

1. **Check package versions**:
   ```bash
   pnpm list cross-spawn glob tar brace-expansion
   ```

2. **Check pnpm version**:
   ```bash
   pnpm --version
   ```

3. **Check Go version in devcontainer**:
   ```bash
   go version  # Should show 1.25.0
   ```

4. **Check golang-migrate version**:
   ```bash
   migrate -version  # Should show v4.20.0
   ```

5. **Rebuild Docker images**:
   ```bash
   docker compose -f docker-compose.build.yml build --no-cache
   ```

6. **Run security audit**:
   ```bash
   pnpm audit
   ```

## Notes

- All npm package fixes are enforced through pnpm overrides to ensure consistent versions across the monorepo
- Alpine Linux package updates are applied during Docker image build
- Go version updated to 1.25.0 to fix multiple stdlib CVEs
- golang-migrate updated to v4.20.0 to include latest security patches
- The pnpm version is updated in all Dockerfiles and package.json to ensure consistency

## Next Steps

1. Rebuild all Docker images to apply the fixes
2. Update CI/CD pipelines to use the new versions
3. Monitor for new CVE reports and update accordingly
4. Consider implementing automated security scanning in CI/CD