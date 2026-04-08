# Architecture (Secure Runtime)

## Node Layout

| Tier | Role | IP | Runtime |
|---|---|---|---|
| Frontend | TLS edge + JS web app | `10.0.10.105` | Nginx (godproxy-style reverse TLS) |
| Backend | Secure API | `10.0.10.102` | Node.js HTTPS API (`8443`) |
| Database | Persistent storage | `10.0.10.106` | MongoDB 7 (`requireTLS`, auth enabled) |

## Data Flow

1. Browser connects to frontend over HTTPS (`443`).
2. Frontend serves static JS app from `frontend/app`.
3. API requests from browser hit `/api/*` on frontend.
4. Nginx reverse proxy forwards `/api/*` to backend over HTTPS (`10.0.10.102:8443`).
5. Proxy injects `X-Internal-Token` for service authentication.
6. Backend validates token, then validates user JWT for protected routes.
7. Backend writes tokenized values to MongoDB over TLS.

## Security Controls

### Edge

- Redirect HTTP to HTTPS.
- TLS 1.2+ only.
- HSTS and response hardening headers.

### Service-to-Service

- Internal API token required for backend route access.
- Backend is intended to be reachable only from frontend node via firewall policy.

### User Authentication

- JWT bearer tokens issued by `/api/auth/login`.
- Protected endpoints require valid bearer token.

### Database

- `security.authorization: enabled`
- `net.tls.mode: requireTLS`
- App writes tokenized sensitive values before persistence.

## Ports

| Source | Destination | Port | Protocol | Purpose |
|---|---|---|---|---|
| User | Frontend | 443 | HTTPS | UI and API entrypoint |
| User | Frontend | 80 | HTTP | Redirect-only |
| Frontend | Backend | 8443 | HTTPS | Reverse-proxied API |
| Backend | Database | 27017 | MongoDB TLS | Data access |

## Deployment Scripts

- Frontend: `frontend/setup_frontend.sh`
- Backend: `backend/setup_backend.sh`
- Database: `database/setup_mongodb_secure.sh`

## Legacy Components

Legacy PHP and legacy MSSQL/CTF assets remain in-repo for reference and historical context.
They are not part of the active secure deployment path.

## Operational Validation

Use:

```bash
bash verify_deployment.sh 10.0.10.105 10.0.10.102 10.0.10.106 "<shared_token_optional>"
```

This verifies encrypted transport, JWT login path, tokenization endpoint behavior, and cross-tier connectivity.
