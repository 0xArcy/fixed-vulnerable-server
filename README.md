# Modern Bank Secure Stack

Modern Bank now runs as an encrypted three-tier deployment with JavaScript frontend delivery, HTTPS backend APIs, and MongoDB over TLS.

## Topology

- Frontend: `10.0.10.105`
- Backend: `10.0.10.102`
- Database: `10.0.10.106`

```
Browser
  |
  | HTTPS (TLS 1.2+)
  v
Frontend (10.0.10.105)
Nginx "godproxy" + JS app
  |
  | HTTPS + X-Internal-Token
  v
Backend (10.0.10.102)
Node.js API (HTTPS only, JWT auth)
  |
  | MongoDB TLS (requireTLS)
  v
Database (10.0.10.106)
MongoDB 7 (auth enabled)
```

## What Changed

1. Frontend migrated to JavaScript app deployment (`frontend/app`) behind Nginx TLS edge.
2. Backend moved to HTTPS-only API with:
   - service-to-service token gate (`X-Internal-Token`)
   - user JWT auth (`Bearer`)
   - deterministic tokenization before MongoDB writes
3. Database tier moved to MongoDB with `requireTLS` and authentication.
4. Deployment scripts updated for encrypted defaults.

## Deployment Order

Run each step on its target machine.

### 1) Database Tier (`10.0.10.106`)

```bash
cd /path/to/vulnerable-bankapp/database
sudo bash setup_mongodb_secure.sh 10.0.10.102
```

Default DB app credentials used by scripts:

- `DB_USER=modernbank_app`
- `DB_PASS=ModernBankMongo!2026`
- `DB_NAME=modernbank`

### 2) Choose Shared Internal API Token

Generate once and reuse on backend + frontend:

```bash
openssl rand -hex 24
```

### 3) Backend Tier (`10.0.10.102`)

```bash
cd /path/to/vulnerable-bankapp/backend
SHARED_TOKEN="<paste_generated_token>"
MONGO_APP_USER=modernbank_app \
MONGO_APP_PASSWORD='ModernBankMongo!2026' \
sudo bash setup_backend.sh 10.0.10.105 10.0.10.106 "$SHARED_TOKEN"
```

### 4) Frontend Tier (`10.0.10.105`)

```bash
cd /path/to/vulnerable-bankapp/frontend
SHARED_TOKEN="<same_token_as_backend>"
sudo bash setup_frontend.sh 10.0.10.102 "$SHARED_TOKEN"
```

### 5) Verify

From an admin workstation:

```bash
bash verify_deployment.sh 10.0.10.105 10.0.10.102 10.0.10.106 "<shared_token_optional>"
```

## Runtime Endpoints

### Frontend

- `https://10.0.10.105/`

### Backend (direct)

- `https://10.0.10.102:8443/api/health` (requires `X-Internal-Token`)

### API through frontend proxy

- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/health`
- `GET /api/db-status`
- `GET /api/records`
- `POST /api/records`
- `GET /api/tokenization/example`

## JavaScript Migration Status

- Active frontend runtime: JavaScript app in `frontend/app`.
- Legacy PHP code under `frontend/www` is retained for reference but not used by the secure deployment scripts.

## Security Controls in Place

- TLS edge on frontend (`443`, HSTS, redirect from `80`).
- TLS backend API (`8443`) with local certificate.
- Frontend-to-backend calls proxied over HTTPS.
- Service-to-service token gate (`X-Internal-Token`) on backend routes.
- User session security via JWT bearer tokens.
- MongoDB `requireTLS` and authentication enabled.
- Sensitive values tokenized before persistence (deterministic HMAC tokenization).

## Notes

- Current scripts default to self-signed certs for bootstrap. Traffic is encrypted; certificate trust pinning can be tightened later by distributing CA files and enabling strict proxy verification.
- If you rotate DB credentials, pass updated values to backend setup via `MONGO_APP_USER` and `MONGO_APP_PASSWORD`.
