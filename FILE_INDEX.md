# 📋 Modern Bank CTF Lab - Complete File Index

**Created:** April 5, 2026  
**Status:** ✅ Complete and Ready for Deployment  
**Location:** `/home/arcy/threetier/`

---

## 📦 Project Deliverables (24 Files Total)

### 📚 Documentation (6 Files)

| File | Purpose | Key Sections |
|------|---------|---|
| **README.md** | Main overview | Quick start, architecture, demo walkthrough |
| **QUICK_START.md** | 45-second guide | Instant deployment, attack phases, tips |
| **PROJECT_SUMMARY.md** | Project overview | Deliverables, statistics, verification |
| **docs/KILL_CHAIN.md** | Attack guide (Comprehensive) | Phase 1-4 detailed, timeline, commands |
| **docs/VULNERABILITIES.md** | Vulnerability catalog | All 21 vulns with CVSS scores, PoC |
| **docs/ARCHITECTURE.md** | System design | Topology, deployment, troubleshooting |

### 🟢 Frontend Tier - Ubuntu LTS (7 Files)

**Location:** `frontend/`

| File | Type | Purpose |
|------|------|---------|
| `setup_frontend.sh` | Bash Script | Automated deployment (Apache2 + PHP) |
| `www/index.php` | PHP | Login page with authentication |
| `www/dashboard.php` | PHP | User dashboard (accounts, transactions) |
| `www/profile.php` | PHP | **VULNERABLE:** File upload (avatar) |
| `www/config.php` | PHP | **EXPOSED:** Backend credentials hardcoded |
| `www/logout.php` | PHP | Session termination |
| `www/css/style.css` | CSS | Modern Bootstrap 5 styling |
| `www/js/app.js` | JavaScript | Client-side form validation |
| `www/uploads/` | Directory | Writable, executable (vulnerable) |

### 🟠 Backend Tier - Ubuntu Server 24 (6 Files)

**Location:** `backend/`

| File | Type | Purpose |
|------|------|---------|
| `setup_backend.sh` | Bash Script | Automated deployment (Node.js + npm) |
| `api/server.js` | Node.js | Express API with 5 vulnerable endpoints |
| `api/admin_cgi.php` | PHP | **VULNERABLE:** Unauthenticated RCE |
| `api/package.json` | JSON | Node.js dependencies (express, axios) |
| `api/.env` | Config | **EXPOSED:** Windows DB credentials |
| `api/credentials.txt` | Text | **EXPOSED:** SSH keys and credentials |

### 🟡 Database Tier - Windows 10 (4 Files)

**Location:** `database/`

| File | Type | Purpose |
|------|------|---------|
| `setup_database.ps1` | PowerShell | Automated deployment (advanced) |
| `setup_database.bat` | Batch | Automated deployment (traditional) |
| `schema.sql` | T-SQL | MSSQL database schema (4 tables, 4 procs) |
| `sample_data.sql` | T-SQL | Sample banking data (users, accounts, transactions) |

### 🔧 Utility Scripts (2 Files)

| File | Purpose |
|------|---------|
| `verify_deployment.sh` | Validates all tiers, runs security tests |
| `.codex` | VS Code settings (generated) |

---

## 🎯 Application Architecture

### **Tier 1: Frontend (Ubuntu LTS - 192.168.1.10)**

**Purpose:** Public-facing web application  
**Technology:** Apache2 + PHP 8.1+  
**Port:** 80, 443

**Features:**
- ✅ Modern banking UI (Bootstrap 5, Tailwind-ready)
- ✅ Authentication system (demo credentials)
- ✅ User dashboard with mock accounts
- ✅ Account balances and transaction history
- ✅ Profile management with avatar upload
- ✅ Session management

**Vulnerabilities (7):**
1. Insecure file upload (extension-only validation)
2. No MIME type checking on server
3. Predictable file paths
4. Web-accessible .env file
5. Hardcoded credentials in source
6. Directory listings enabled
7. Execute permissions on uploads

---

### **Tier 2: Backend (Ubuntu Server 24 - 192.168.1.100)**

**Purpose:** Internal API and business logic  
**Technology:** Node.js + Express.js  
**Port:** 8080

**Endpoints:**
- `GET /api/health` - Health check
- `GET /api/config` - **VULNERABLE:** Configuration dump with credentials
- `POST /api/proxy` - **VULNERABLE:** SSRF endpoint
- `GET /cgi-bin/admin.php` - **VULNERABLE:** Unauthenticated RCE
- `POST /api/callback` - **VULNERABLE:** Callback injection
- `GET /api/logs` - Request logging endpoint

**Vulnerabilities (8):**
1. SSRF via /api/proxy
2. Unauthenticated admin endpoint
3. Command injection in CGI
4. Configuration disclosure
5. Exposed environment variables
6. Request logging
7. Callback RCE
8. No network segmentation

---

### **Tier 3: Database (Windows 10 - 192.168.1.50)**

**Purpose:** Data storage and admin services  
**Technology:** SQL Server Express (MSSQL)  
**Port:** 1433 (MSSQL), 3389 (RDP), 445 (SMB)

**Database Schema:**
- `Users` - User accounts (4 columns)
- `Accounts` - Banking accounts (8 columns)
- `Transactions` - Financial transactions (9 columns)
- `AuditLog` - Activity logging (6 columns)

**Stored Procedures:**
- `sp_AuthenticateUser` - Authentication (vulnerable)
- `sp_GetUserAccounts` - Account listing
- `sp_ExecuteQuery` - Query execution (SQL injection ready)
- `sp_ExportAllData` - Data export

**Vulnerabilities (6):**
1. Weak database credentials
2. Overprivileged application user
3. xp_cmdshell enabled (RCE)
4. Exposed Windows credentials file
5. Firewall allows all from Backend
6. No privilege change audit logging

---

## 🔐 Security Features (Intentional Vulnerabilities)

### By Category

**Authentication (3):**
- Weak hardcoded credentials (admin/admin123)
- No multi-factor authentication
- Session token in URL

**Authorization (2):**
- No authentication on admin endpoints
- Overprivileged database users

**Input Validation (5):**
- Extension-only file validation
- Command injection in CGI
- SQL injection ready stored procedures
- No MIME type checking
- Directory traversal possible

**Sensitive Data (6):**
- Credentials in .env file
- Credentials in source code
- SSH keys exposed
- Windows password in file
- Unencrypted credentials transmission
- API exposes all configuration

**Network Security (5):**
- No encryption between tiers
- No network segmentation
- Open firewall rules
- SSRF vulnerability
- Internal service exposure

---

## 📊 Statistics

| Metric | Count |
|--------|-------|
| **Total Files** | 24 |
| **PHP Files** | 5 |
| **JavaScript Files** | 1 |
| **Node.js Files** | 1 |
| **Shell Scripts** | 3 |
| **PowerShell Scripts** | 1 |
| **SQL Scripts** | 2 |
| **Documentation Files** | 6 |
| **Total Lines of Code** | ~5,000+ |
| **Web Pages** | 5 |
| **API Endpoints** | 6+ |
| **Database Tables** | 4 |
| **Stored Procedures** | 4 |
| **Vulnerabilities** | 21 |
| **Attack Phases** | 4 |

---

## 🚀 Quick Deployment Summary

### Step 1: Frontend (5 minutes)

```bash
# SSH to: ubuntu@192.168.1.10
cd /tmp && git clone <repo> threetier && cd threetier/frontend
sudo bash setup_frontend.sh 192.168.1.100
# ✅ Result: http://192.168.1.10 working
```

### Step 2: Backend (5 minutes)

```bash
# SSH to: ubuntu@192.168.1.100
cd /tmp && git clone <repo> threetier && cd threetier/backend
sudo bash setup_backend.sh 192.168.1.10 192.168.1.50
# ✅ Result: http://192.168.1.100:8080/api/health working
```

### Step 3: Database (5 minutes)

```powershell
# PowerShell as Administrator on Windows 10
cd C:\repo\database
.\setup_database.ps1 -BackendIP 192.168.1.100
# ✅ Result: MSSQL responding on 1433
```

### Step 4: Verify (1 minute)

```bash
bash verify_deployment.sh 192.168.1.10 192.168.1.100 192.168.1.50
# ✅ All checks pass
```

**Total Setup Time: ~20 minutes**

---

## 📖 Documentation Roadmap

```
START HERE
    ↓
README.md (5 min read)
    ↓
QUICK_START.md (2 min read)
    ↓
Choose Your Path:
    ├─→ Want to deploy? → ARCHITECTURE.md
    ├─→ Want to attack? → KILL_CHAIN.md
    └─→ Want details? → VULNERABILITIES.md
    ↓
Start Exploitation!
```

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] 3 VMs prepared (Ubuntu LTS, Ubuntu Server, Windows 10)
- [ ] Network configured (192.168.1.0/24)
- [ ] IPs assigned (10, 100, 50)
- [ ] Firewall rules planned
- [ ] Git access to repository

### Deployment
- [ ] Frontend setup script runs successfully
- [ ] Backend setup script runs successfully
- [ ] Database setup script runs successfully
- [ ] All services start without errors
- [ ] Firewall rules configured

### Verification
- [ ] Frontend responds on HTTP 80
- [ ] Backend responds on HTTP 8080
- [ ] Database responds on TCP 1433
- [ ] `.env` file is readable
- [ ] API endpoints return data
- [ ] File upload works
- [ ] Credentials are exposed

### Testing
- [ ] Can login to frontend
- [ ] Can upload files
- [ ] Can read .env
- [ ] Can SSH to backend
- [ ] Can query database
- [ ] All vulnerabilities confirmed

---

## 🎓 Attack Learning Path

### Phase 1: File Upload RCE (Frontend)
**Time:** ~5 min  
**Skills:** Web app testing, PHP exploitation  
**Tools:** Browser, curl  

### Phase 2: Credential Harvesting
**Time:** ~5 min  
**Skills:** File enumeration, source code analysis  
**Tools:** Browser, curl, grep  

### Phase 3: Lateral Movement
**Time:** ~5 min  
**Skills:** SSH access, network pivoting  
**Tools:** SSH client, web shell  

### Phase 4: Network Reconnaissance
**Time:** ~10 min  
**Skills:** API enumeration, SSRF exploitation  
**Tools:** curl, nmap, Burp Suite (optional)  

### Phase 5: Database Access
**Time:** ~10 min  
**Skills:** MSSQL connection, SQL queries  
**Tools:** sqlcmd, impacket, DBeaver  

### Phase 6: Privilege Escalation
**Time:** ~5 min  
**Skills:** Database escalation, xp_cmdshell  
**Tools:** sqlcmd, SQL queries  

### Phase 7: Persistence
**Time:** ~10 min  
**Skills:** Backdoor creation, system access  
**Tools:** RDP, command line  

**Total Time: ~50 minutes for complete compromise**

---

## 🛠️ Customization Options

### Difficulty Levels

**Easy:** All files visible, credentials everywhere, hints provided  
**Medium:** Standard setup (as delivered)  
**Hard:** Credentials obfuscated, limited hints, strict firewall  
**Extreme:** No hints, AV simulation, blind RCE only

### Modifications

- Change all IPs and passwords
- Add additional vulnerabilities
- Remove documentation
- Randomize file names
- Add decoy services
- Enable logging detection
- Add rate limiting
- Implement basic WAF

---

## 📞 Support & Troubleshooting

### Can't Deploy Frontend?
→ See `docs/ARCHITECTURE.md` - Frontend troubleshooting section

### Backend API not responding?
→ Check: `sudo systemctl status modernbank-backend`

### Database won't start?
→ See `docs/ARCHITECTURE.md` - Database troubleshooting section

### Want to reset?
→ All setup scripts can be re-run to reset state

### Need help?
→ All vulnerabilities documented in `docs/VULNERABILITIES.md`

---

## 🎯 Success Criteria

You've successfully deployed the lab when:

✅ Frontend web app loads at http://192.168.1.10  
✅ Login works with admin/admin123  
✅ File upload functionality works  
✅ Backend API responds at port 8080  
✅ Admin endpoint accessible without auth  
✅ Database responds on port 1433  
✅ All 21 vulnerabilities are exploitable  
✅ Attack chain can be completed in <1 hour  

---

## 🚀 Next Steps

1. **Read:** [README.md](README.md) - 5 minute overview
2. **Deploy:** Run the 3 setup scripts
3. **Verify:** Run `verify_deployment.sh`
4. **Learn:** Follow [QUICK_START.md](QUICK_START.md) - 45 second attack
5. **Deep Dive:** Study [KILL_CHAIN.md](docs/KILL_CHAIN.md) - complete guide
6. **Reference:** Check [VULNERABILITIES.md](docs/VULNERABILITIES.md) - all details

---

## 📝 File Ready Status

| Component | Status | Ready |
|-----------|--------|-------|
| Frontend App | Complete | ✅ |
| Backend API | Complete | ✅ |
| Database Schema | Complete | ✅ |
| Setup Scripts | Complete | ✅ |
| Documentation | Complete | ✅ |
| Test Scripts | Complete | ✅ |
| Demo Data | Complete | ✅ |
| UI/UX | Complete | ✅ |
| Vulnerabilities | Complete | ✅ |
| Attack Guides | Complete | ✅ |

---

## 🎉 You Have Everything!

This complete 3-tier CTF laboratory includes:

✅ **Complete Source Code** (24 ready-to-deploy files)  
✅ **Automated Setup Scripts** (3 deployment scripts)  
✅ **Modern UI/UX** (Polished banking application)  
✅ **Real Vulnerabilities** (21 intentional security flaws)  
✅ **Complete Documentation** (6 comprehensive guides)  
✅ **Attack Guides** (Phase-by-phase exploitation)  
✅ **Deployment Scripts** (Bash, PowerShell, Batch)  
✅ **Verification Tools** (Automated testing)  
✅ **Sample Data** (Realistic banking scenarios)  
✅ **Ready to Deploy** (All files parameterized and tested)

---

## 📍 Location

All files are located in:

```
/home/arcy/threetier/
```

Perfect for cloning to multiple VMs or deployment platforms.

---

**Status: ✅ READY FOR DEPLOYMENT**

**Start with:** [README.md](README.md)  
**Then read:** [QUICK_START.md](QUICK_START.md)  
**Follow along:** [docs/KILL_CHAIN.md](docs/KILL_CHAIN.md)

Happy hacking! 🎯
