# ZERO-CLICK MODERNBANK DEPLOYMENT GUIDE

The entire deployment infrastructure has been securely refactored to an encrypted-by-default, tokenized stack utilizing:
- **MongoDB (Windows 10, Port 27017)**: Fully enforced TLS & Authentication.
- **Node.js Backend (Ubuntu Server, Port 443)**: Express API protected by internal tokens and TLS.
- **Nginx Frontend Proxy (Ubuntu OS, Port 443)**: Static React/Vanilla app acting as an API gateway.

## Environment Variables / IP Config
| Node | IP Address | Subnet | Role |
|------|------------|--------|------|
| **Database** | `10.0.10.106` | /24 | Windows 10, MongoDB TLS |
| **Backend** | `10.0.10.102` | /24 | Ubuntu Server, Node.js + PM2 |
| **Frontend** | `10.0.10.105` | /24 | Ubuntu OS, Next.js / Vanilla + Nginx |

---

## 1. Deploy Database (Windows 10)
Run the script on Windows 10 (`10.0.10.106`) as **Administrator**.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\database\setup_mongo.ps1 -BackendIP "10.0.10.102"
```
*(This sets up MongoDB natively with TLS certificates and drops the explicit `requireTLS` configuration.)*

## 2. Deploy Backend (Ubuntu Server)
Connect to `10.0.10.102`. A single master-token is required for internal gateway mapping. Let's assume you generated it: E.g., `modernbank_token_999`.

```bash
sudo bash ./backend/setup_node.sh 10.0.10.105 10.0.10.106 modernbank_token_999
```

## 3. Deploy Frontend (Ubuntu OS)
Connect to `10.0.10.105`. The proxy relies on the backend and matching token to operate properly!

```bash
sudo bash ./frontend/setup_nginx_proxy.sh 10.0.10.102 modernbank_token_999
```

## 4. Verification Check
Use the pre-built verification script from your orchestration machine:

```bash
bash verify_stack.sh 10.0.10.105 10.0.10.102 10.0.10.106 modernbank_token_999
```

Everything is fully migrated from PHP to JS, and from clear-text SQL to Encrypted MongoDB!
