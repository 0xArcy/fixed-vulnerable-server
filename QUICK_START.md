# Quick Start (Secure Deployment)

This guide brings up the encrypted Modern Bank stack with the default node layout:

- Backend: `10.0.10.102`
- Frontend: `10.0.10.105`
- Database: `10.0.10.106`

## 1. Database Node (`10.0.10.106`)

```bash
cd /path/to/vulnerable-bankapp/database
sudo bash setup_mongodb_secure.sh 10.0.10.102
```

This configures:

- MongoDB with `authorization: enabled`
- `requireTLS` on port `27017`
- firewall rule allowing backend node to reach MongoDB

## 2. Shared Internal Token (generate once)

Run on any admin host:

```bash
openssl rand -hex 24
```

Save this value as `SHARED_TOKEN` and use exactly the same token on backend and frontend setup commands.

## 3. Backend Node (`10.0.10.102`)

```bash
cd /path/to/vulnerable-bankapp/backend
SHARED_TOKEN="<generated_token>"
MONGO_APP_USER=modernbank_app \
MONGO_APP_PASSWORD='ModernBankMongo!2026' \
sudo bash setup_backend.sh 10.0.10.105 10.0.10.106 "$SHARED_TOKEN"
```

This configures:

- HTTPS-only Node API on `8443`
- service token validation (`X-Internal-Token`)
- JWT auth endpoints
- tokenization before MongoDB writes

## 4. Frontend Node (`10.0.10.105`)

```bash
cd /path/to/vulnerable-bankapp/frontend
SHARED_TOKEN="<same_generated_token>"
sudo bash setup_frontend.sh 10.0.10.102 "$SHARED_TOKEN"
```

This configures:

- Nginx TLS edge (`443`) with HTTP redirect from `80`
- JS frontend from `frontend/app`
- reverse-proxy route `/api/*` to backend HTTPS
- automatic `X-Internal-Token` forwarding

## 5. Verify End-To-End

```bash
cd /path/to/vulnerable-bankapp
bash verify_deployment.sh 10.0.10.105 10.0.10.102 10.0.10.106 "$SHARED_TOKEN"
```

## 6. Login Test

Open:

- `https://10.0.10.105/`

Use:

- Username: `julia.ross`
- Password: `BankDemo!2026`

## 7. Expected Results

- Frontend page loads only over HTTPS.
- API health works through frontend proxy.
- JWT login succeeds.
- Database status returns `"mongo_transport":"tls"`.
- Creating a record stores tokenized values (token starts with `tok_`).
