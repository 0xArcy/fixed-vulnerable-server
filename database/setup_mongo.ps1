# Setup Database (MongoDB on Windows 10)
# Requirements: Run as Administrator

param (
    [string]$BackendIP = "10.0.10.102",
    [string]$DbUser = "modernbank_app",
    [string]$DbPassword = "ModernBankMongo!2026"
)

Write-Host "Setting up modernbank database on Windows..."
# Ensure Admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run Windows PowerShell as Administrator."
    Exit
}

$MongoUrl = "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-7.0.2-signed.msi"
$InstallerPath = "$env:TEMP\mongodb.msi"

if (-Not (Test-Path "C:\Program Files\MongoDB\Server\7.0\bin\mongod.exe")) {
    Write-Host "Downloading MongoDB..."
    Invoke-WebRequest -Uri $MongoUrl -OutFile $InstallerPath
    Write-Host "Installing MongoDB..."
    Start-Process msiexec.exe -Wait -ArgumentList "/i $InstallerPath /qn /norestart"
}

Write-Host "Generating TLS Certificate for MongoDB..."
$MongoPath = "C:\Program Files\MongoDB\Server\7.0"
$CertPath = "$MongoPath\cert"
if (-Not (Test-Path $CertPath)) { New-Item -ItemType Directory -Force -Path $CertPath | Out-Null }

$cert = New-SelfSignedCertificate -DnsName "10.0.10.106", "localhost" -CertStoreLocation "cert:\LocalMachine\My"
$certPassword = ConvertTo-SecureString -String "MongoTlsPass2026@" -Force -AsPlainText
$pfxPath = "$CertPath\mongo.pfx"
$pemPath = "$CertPath\mongo.pem"

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $certPassword | Out-Null
Set-Location $CertPath

$bytes = [System.IO.File]::ReadAllBytes($pfxPath)
$collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$collection.Import($bytes, "MongoTlsPass2026@", [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
$certString = $collection[0].Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
$base64Cert = [Convert]::ToBase64String($certString)

$pemBlock = "-----BEGIN CERTIFICATE-----`n"
for ($i = 0; $i -lt $base64Cert.Length; $i += 64) {
    if ($base64Cert.Length - $i -ge 64) { $pemBlock += $base64Cert.Substring($i, 64) + "`n" }
    else { $pemBlock += $base64Cert.Substring($i, $base64Cert.Length - $i) + "`n" }
}
$pemBlock += "-----END CERTIFICATE-----`n"

$rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($collection[0])
$privKeyBytes = $rsa.ExportRSAPrivateKey()
$base64PrivKey = [Convert]::ToBase64String($privKeyBytes)
$privBlock = "-----BEGIN RSA PRIVATE KEY-----`n"
for ($i = 0; $i -lt $base64PrivKey.Length; $i += 64) {
    if ($base64PrivKey.Length - $i -ge 64) { $privBlock += $base64PrivKey.Substring($i, 64) + "`n" }
    else { $privBlock += $base64PrivKey.Substring($i, $base64PrivKey.Length - $i) + "`n" }
}
$privBlock += "-----END RSA PRIVATE KEY-----`n"

$pemBlock + $privBlock | Out-File -FilePath $pemPath -Encoding ASCII -Force

$ConfigCdata = @"
systemLog:
  destination: file
  path: $MongoPath\log\mongod.log
  logAppend: true
storage:
  dbPath: $MongoPath\data
net:
  port: 27017
  bindIp: 0.0.0.0
  tls:
    mode: requireTLS
    certificateKeyFile: $pemPath
security:
  authorization: enabled
"@
$ConfigCdata | Out-File -FilePath "$MongoPath\bin\mongod.cfg" -Encoding ASCII -Force

Write-Host "Restarting MongoDB service..."
Restart-Service MongoDB

Write-Host "Creating app user... Please give it 10 seconds..."
Start-Sleep -Seconds 10
& "$MongoPath\bin\mongo.exe" --tls --tlsAllowInvalidCertificates --eval "db.getSiblingDB('admin').createUser({user: '$DbUser', pwd: '$DbPassword', roles: [{role: 'readWrite', db: 'bank'}]})"

Write-Host "Firewall: Allowing MongoDB port 27017 from Backend IP..."
New-NetFirewallRule -DisplayName "MongoDB" -Direction Inbound -LocalPort 27017 -Protocol TCP -RemoteAddress $BackendIP -Action Allow

Write-Host "MongoDB setup complete on Windows 10 (10.0.10.106) with TLS Enforced."
