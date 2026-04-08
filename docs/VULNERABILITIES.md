# Security Findings Status

This document tracks current security posture after the secure migration to:

- JavaScript frontend (`frontend/app`) behind TLS edge proxy
- HTTPS backend API with service-token and JWT controls
- MongoDB with TLS + authentication

## Scope Note

Legacy CTF-oriented files are still present in the repository (`frontend/www`, old Windows DB scripts, and historical docs), but they are not part of the active secure deployment path.

Active deployment scripts:

- `frontend/setup_frontend.sh`
- `backend/setup_backend.sh`
- `database/setup_mongodb_secure.sh`

## Findings Matrix

| ID | Area | Previous Risk | Current Status | Notes |
|---|---|---|---|---|
| MB-SEC-001 | Frontend transport | Plain HTTP exposure | **Remediated** | Nginx now redirects `80 -> 443`; frontend served over TLS |
| MB-SEC-002 | Frontend-to-backend trust | Unauthenticated cross-tier API calls | **Remediated** | Backend requires `X-Internal-Token`; frontend proxy injects token |
| MB-SEC-003 | Backend API transport | HTTP backend API | **Remediated** | Backend now serves HTTPS only (`8443`) |
| MB-SEC-004 | User session security | Mock/weak auth model | **Remediated (baseline)** | JWT bearer tokens required for user endpoints |
| MB-SEC-005 | Database transport | Unencrypted DB link | **Remediated** | MongoDB configured with `requireTLS` |
| MB-SEC-006 | Data-at-rest exposure in app layer | Sensitive values stored directly | **Remediated (tokenization)** | Deterministic HMAC tokenization before persistence |
| MB-SEC-007 | Direct backend exposure | Open backend API surface | **Improved** | Intended policy is frontend-proxy path; backend route gating in place |
| MB-SEC-008 | Upload RCE path (legacy PHP profile) | Unrestricted file upload execution | **Remediated** | See `docs/FILE_UPLOAD_REMEDIATION_OWASP_CVE.md` |

## Remaining Risks / Hardening Backlog

1. Certificate trust chain is currently bootstrap self-signed.
   - Traffic is encrypted, but strict CA validation between tiers should be enforced in production.
2. Legacy code remains in-repo.
   - Recommend archiving or deleting unused vulnerable legacy paths after final migration validation.
3. Secrets are generated/deployed through setup scripts.
   - Recommend integrating a secrets manager and periodic secret rotation policy.
4. No centralized SIEM shipping in current scripts.
   - Recommend forwarding Nginx, backend app, and MongoDB auth logs to centralized monitoring.

## Validation Checklist

1. `https://10.0.10.105` loads successfully.
2. `http://10.0.10.105` redirects to HTTPS.
3. Login returns JWT token (`/api/auth/login` through frontend).
4. `/api/db-status` reports `"mongo_transport":"tls"`.
5. Record creation returns tokenized fields with `tok_` prefix.
6. Direct backend call without internal token is denied.

## Related Documents

- `README.md`
- `QUICK_START.md`
- `docs/ARCHITECTURE.md`
- `docs/FILE_UPLOAD_REMEDIATION_OWASP_CVE.md`
