# Modern Bank CTF Lab - Project Summary

## 📦 Deliverables

### Complete Codebase

#### Frontend Tier (Ubuntu LTS)
- `frontend/setup_frontend.sh` - Automated deployment script
- `frontend/www/index.php` - Login page
- `frontend/www/dashboard.php` - User dashboard with mock accounts
- `frontend/www/profile.php` - Profile management (VULNERABLE upload)
- `frontend/www/config.php` - Configuration with exposed credentials
- `frontend/www/logout.php` - Session termination
- `frontend/www/css/style.css` - Modern Bootstrap 5 styling
- `frontend/www/js/app.js` - Client-side JavaScript
- `frontend/www/uploads/` - Avatar directory (writable, vulnerable)

#### Backend Tier (Ubuntu Server 24)
- `backend/setup_backend.sh` - Automated deployment script
- `backend/api/server.js` - Express.js API with SSRF, RCE endpoints
- `backend/api/admin_cgi.php` - Unauthenticated CGI admin interface
- `backend/api/package.json` - Node.js dependencies
- `backend/api/.env` - Environment config with hardcoded Windows credentials
- `backend/api/credentials.txt` - Exposed SSH key and credentials

#### Database Tier (Windows 10)
- `database/setup_database.bat` - Batch deployment script
- `database/setup_database.ps1` - PowerShell deployment (advanced)
- `database/schema.sql` - MSSQL database schema
- `database/sample_data.sql` - Sample banking data (users, accounts, transactions)
- `database/firewall_config.ps1` - Windows firewall configuration

#### Documentation
- `docs/KILL_CHAIN.md` - Complete attack walkthrough (Phase 1-4)
- `docs/VULNERABILITIES.md` - Detailed vulnerability catalog
- `docs/ARCHITECTURE.md` - System design and deployment guide
- `README.md` - Project overview and quick start
- `verify_deployment.sh` - Deployment verification script

### Key Features

#### Application UI/UX
- **Modern Design:** Bootstrap 5 with custom CSS
- **Professional Banking Interface:** Dashboard with account balances, transactions
- **Responsive Layout:** Mobile-friendly design
- **Polished Components:** Cards, tables, modals, alerts
- **Interactive Elements:** Forms with validation, upload functionality

#### Gaming Engine
1. **Frontend Entry Point:** File upload vulnerability leading to PHP shell
2. **Credential Exposure:** .env file with Backend SSH credentials
3. **Lateral Movement:** SSH access to Backend tier from Frontend shell
4. **Backend Exploitation:** SSRF, unauthenticated admin endpoints
5. **Database Access:** MSSQL with weak credentials and xp_cmdshell
6. **Complete Compromise:** Creation of backdoor admin user

#### Parameterized Deployment
- All scripts accept IP addresses as command-line arguments
- `setup_frontend.sh <BACKEND_IP>` - Configures backend connectivity
- `setup_backend.sh <FRONTEND_IP> <WINDOWS_IP>` - Multi-tier configuration
- `setup_database.ps1 -BackendIP <IP>` - Dynamic firewall rules

#### Automated Setup
- System dependency installation
- Service configuration and startup
- Firewall rule configuration
- Environment variable injection
- Database schema creation and sample data population

---

## 🔐 Intentional Vulnerabilities (21 Total)

### Frontend Tier (7 vulnerabilities)
1. Insecure file upload (extension-only validation)
2. No MIME type checking
3. Predictable file paths
4. Web-accessible .env file
5. Hardcoded credentials in PHP source
6. Directory listings enabled
7. Execute permissions on uploads directory

### Backend Tier (8 vulnerabilities)
1. SSRF via /api/proxy endpoint
2. Unauthenticated admin endpoint
3. Command injection in CGI
4. Configuration disclosure endpoint
5. Exposed environment variables
6. Request logging endpoint
7. Callback RCE endpoint
8. No network segmentation

### Database Tier (6 vulnerabilities)
1. Weak database credentials
2. Overprivileged application user
3. xp_cmdshell enabled
4. Exposed Windows credentials file
5. Firewall allows all from Backend
6. No audit logging for privilege changes

---

## 📊 Project Statistics

| Metric | Value |
|--------|-------|
| Total Files | 21 |
| PHP Files | 5 |
| JavaScript Files | 2 |
| Shell Scripts | 2 |
| PowerShell Scripts | 1 |
| Batch Scripts | 1 |
| SQL Scripts | 1 |
| Documentation Files | 4 |
| Configuration Files | 2 |
| Total Lines of Code | ~5,000+ |
| Frontend UI Components | 10+ |
| API Endpoints | 10+ |
| Database Tables | 4 |
| Stored Procedures | 4 |

---

## 🚀 Quick Deployment Command Sequence

```bash
# FRONTEND (Ubuntu LTS - 192.168.1.10)
ssh ubuntu@192.168.1.10
git clone <repo> /tmp/threetier
cd /tmp/threetier/frontend
sudo bash setup_frontend.sh 192.168.1.100

# BACKEND (Ubuntu Server 24 - 192.168.1.100)
ssh ubuntu@192.168.1.100
git clone <repo> /tmp/threetier
cd /tmp/threetier/backend
sudo bash setup_backend.sh 192.168.1.10 192.168.1.50

# DATABASE (Windows 10 - 192.168.1.50)
# PowerShell as Administrator
PowerShell -ExecutionPolicy Bypass
cd C:\repo\database
.\setup_database.ps1 -BackendIP 192.168.1.100

# VERIFY (from any machine)
bash verify_deployment.sh 192.168.1.10 192.168.1.100 192.168.1.50
```

---

## 📚 Attack Training Path

1. **Phase 1:** Web application exploitation (file upload RCE)
2. **Phase 2:** Credential harvesting (env file extraction)
3. **Phase 3:** Lateral movement (SSH to backend)
4. **Phase 4:** Network reconnaissance (API enumeration)
5. **Phase 5:** Database access (MSSQL connection)
6. **Phase 6:** Privilege escalation (xp_cmdshell activation)
7. **Phase 7:** Persistence (backdoor creation)

---

## 🛠️ Technical Stack

### Frontend
- Apache2 (web server)
- PHP 8.1+ (application framework)
- Bootstrap 5 (CSS framework)
- JavaScript (client-side interactivity)

### Backend
- Node.js 20+ (JavaScript runtime)
- Express.js (REST API framework)
- PHP CLI (CGI endpoints)
- axios (HTTP client)

### Database
- Microsoft SQL Server Express (DBMS)
- T-SQL (stored procedures and queries)
- Windows authentication
- Native Protocols (Named Pipes, TCP/IP)

### Deployment
- Bash (Linux scripting)
- PowerShell (Windows scripting)
- systemd (Linux service management)
- Windows Services (Windows service management)

---

## ✅ Success Criteria

Deployment is successful when:

1. ✓ Frontend web app accessible at http://192.168.1.10
2. ✓ Can login with demo credentials
3. ✓ Can upload files to profile picture
4. ✓ .env file is readable via web
5. ✓ Backend API responds at http://192.168.1.100:8080
6. ✓ Admin endpoint accessible without authentication
7. ✓ MSSQL database listening on port 1433
8. ✓ RDP and SMB services running
9. ✓ Firewall rules configured per tier
10. ✓ Sample data populated in database

---

## 🧪 Verification Steps

```bash
# Test Frontend
curl http://192.168.1.10 | grep "Modern Bank"

# Test Backend
curl http://192.168.1.100:8080/api/health

# Test Database
sqlcmd -S 192.168.1.50 -U Administrator -P "ModernBank@2024!Admin" -Q "SELECT 1"

# Test Vulnerability (Frontend)
curl http://192.168.1.10/.env

# Test Vulnerability (Backend)
curl http://192.168.1.100:8080/cgi-bin/admin.php?action=info

# Full verification script
bash verify_deployment.sh
```

---

## 📖 Documentation Included

1. **README.md** - Project overview, quick start, demo walkthrough
2. **KILL_CHAIN.md** - Complete step-by-step attack guide (Phase 1-4)
3. **VULNERABILITIES.md** - Technical details of each vulnerability
4. **ARCHITECTURE.md** - System design, deployment, troubleshooting

Each document includes:
- Attack vectors and exploitation techniques
- Code snippets and command examples
- Expected outputs and success indicators
- Detailed explanations for learning

---

## 🎯 Learning Outcomes

Students completing this lab will understand:

- Web application security (file uploads, credential management)
- Network segmentation and firewall rules
- API security and information disclosure
- Lateral movement across network tiers
- Database security and privilege escalation
- Persistence and backdoor installation
- Real-world attack chaining and multi-stage exploitation

---

## 📝 Notes

- All vulnerabilities are **intentional** for training
- The application is **NOT suitable for production**
- Use only in **isolated lab environments**
- Recommended for **authorized penetration testing** only
- Created for **educational purposes** in cybersecurity training
- Fully **documented** for instructor and student use

---

## 🚀 Ready for Deployment!

All files are organized, documented, and ready for immediate deployment on the three-tier lab environment. Scripts are robust with error handling, clear logging, and success verification.

**Estimated Setup Time:** 30-45 minutes per tier

See `README.md` for quick start and `docs/KILL_CHAIN.md` for exploitation guide.
