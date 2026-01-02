# Commit Message (Conventional Commits Format)

```
security: fix multiple CVE vulnerabilities in dependencies

- Update pnpm from 9.5.0 to 9.15.0 (CVE-2024-47829, CVE-2024-53866)
- Update cross-spawn to ^7.0.6 (CVE-2024-21538)
- Ensure glob ^11.1.0 and tar ^7.5.2 overrides (CVE-2025-64756, CVE-2025-64118)
- Ensure brace-expansion ^2.0.2 override (CVE-2025-5889)
- Update Alpine packages in Dockerfiles (CVE-2025-60876)

BREAKING CHANGE: pnpm version updated from 9.5.0 to 9.15.0

Fixes: CVE-2024-21538, CVE-2025-64756, CVE-2024-47829, CVE-2025-60876, 
       CVE-2025-64118, CVE-2024-53866, CVE-2025-5889
```

## Alternative shorter version:

```
security: update dependencies to fix 7 CVE vulnerabilities

- Update pnpm to 9.15.0 (fixes CVE-2024-47829, CVE-2024-53866)
- Update cross-spawn to ^7.0.6 (fixes CVE-2024-21538)
- Update Alpine packages in Dockerfiles
- Ensure latest versions of glob, tar, brace-expansion

Resolves 7 security vulnerabilities with severity ranging from 1.3L to 7.7H
```