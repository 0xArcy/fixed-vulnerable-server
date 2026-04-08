# ModernBank - Security Migration & Hardening Report

This document details the exact security vulnerabilities present in the legacy architecture and how they were mitigated in the newly deployed Stack.

## 1. Architecture Overhaul: From Cleartext to E2E Encryption
**Previously:** The 3-tier setup (PHP Frontend -> PHP Backend -> SQL Database) communicated entirely over cleartext HTTP and unencrypted SQL protocols (Port 1433/3306). Anyone on the subnet could wiretap passwords and session tokens.
**Now:** E2E TLS Encryption is enforced across the entire stack.
*   **Nginx Reverse Proxy (Frontend):** Terminates HTTPS and proxies internally via TLS. 
*   **Express.js (Backend):** Serves `https://` natively using local private keys.
*   **MongoDB (Database):** Enforces `requireTLS: true`. Connections are rejected if they lack the internal `mongo.pem` certificate handshake. 

## 2. Authentication: Removing DOM XSS Vectors
**Previously:** The frontend managed Authentication by dropping JWTs or Session IDs into the browser's `localStorage`. If a single Cross-Site Scripting (XSS) vulnerability existed, an attacker could extract `localStorage.getItem('token')` and permanently hijack the user's bank session.
**Now:** HttpOnly, Secure, SameSite Cookies.
*Tokens never touch frontend JavaScript.* The Backend issues an `access_token` inside a strict `HttpOnly` cookie. The browser inherently sends it with `credentials: 'include'`, totally neutralizing DOM-based token extraction.

## 3. Database Hardening & Credential Masking
**Previously:** The SQL database used a hardcoded, over-privileged `sa` (system admin) or `root` account without password hashing (storing user passwords in plain text).
**Now:** Password Hashing & Least Privilege schemas using MongoDB.
*   User passwords (like `BankDemo!2026`) are never stored raw. We use `crypto.pbkdf2Sync` to hash them with AES-512 level salts.
*   Database Firewalling: The Windows 10 DB strictly rejects all IP addresses EXCEPT the Backend (`10.0.10.102`), neutralizing direct database access attacks even if credentials leak.

## 4. Secure Script Deployments (One-Click Zero-Touch)
**Previously:** Deployment required manually editing `.env` files, running multiple `.bat` or `.php` migrations, and passing creds across unencrypted text files (`CREDENTIALS.txt`).
**Now:** Everything is automated.
*   **Windows DB (`setup_mongo.ps1`):** Downloads the MongoDB MSI, installs it silently, generates internal SSL certificates, boots the engine, and punches the firewall rule for you.
*   **Ubuntu Server Backend (`setup_node.sh`):** Downloads Node.js, injects `.env` securely on the fly, hashes random secrets (`openssl rand`), and permanently daemons the server using `PM2`.
*   **Ubuntu OS Frontend (`setup_nginx_proxy.sh`):** Installs Nginx, generates SSL arrays, and embeds OWASP Top 10 headers (HSTS, X-Frame-Options, CSP) into the live traffic instantly.

You simply run **one script per machine** and the system builds its own secure mesh.
