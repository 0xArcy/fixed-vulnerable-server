# File Upload Remediation Report (OWASP + CVE)

Date: 2026-04-08  
Application: Modern Bank frontend (`frontend/www`)  
Scope: Avatar upload flow and upload-serving path

## 1. What was fixed

The avatar upload path was vulnerable to unrestricted file upload and unsafe storage behavior.

Before this remediation, the implementation accepted user-controlled file extensions, wrote files directly into a web-accessible directory, and applied permissive file/directory permissions. In practical terms, an attacker could upload non-image content and attempt code execution or content hosting from the application web root.

This remediation implements a defense-in-depth upload pipeline:

1. Strict server-side validation.
2. MIME and image parsing validation.
3. Image re-encoding (content normalization).
4. Private storage outside web root.
5. Authenticated serving through a controlled endpoint.
6. CSRF protection on the upload action.
7. Permission hardening in deployment automation.

## 2. Code-level change log

| File | Change | Security value |
|---|---|---|
| `frontend/www/config.php` | Added hardened upload policy and helper functions (`validateUpload`, `storeAvatarUpload`, `getAvatarStoragePath`, `getAvatarUrl`) | Moves trust decisions to server-side code; rejects non-image payloads; normalizes image bytes before persistence |
| `frontend/www/profile.php` | Replaced insecure upload flow with CSRF-validated POST flow; wired to `storeAvatarUpload` | Blocks CSRF abuse and stops raw file write behavior |
| `frontend/www/avatar.php` (new) | Added authenticated avatar delivery endpoint with user-id authorization and safe headers | Prevents direct arbitrary file execution/serving from upload folder |
| `frontend/www/authenticate.php` | Loads avatar URL via secure resolver (`getAvatarUrl`) | Keeps rendering path consistent with secured storage model |
| `frontend/www/includes/bootstrap.php` | Default avatar path moved to `/assets/default-avatar.svg` | Removes dependence on `/uploads` for defaults |
| `frontend/www/uploads/.htaccess` (new) | Disabled directory listing and common PHP execution handlers in legacy upload directory | Defense in depth if legacy `/uploads` is ever reused |
| `frontend/setup_frontend.sh` | Deployment now creates `/var/www/private/avatars` with locked permissions, lower upload limits, and no web-root indexing | Prevents environment-level reintroduction of upload exploitation paths |
| `frontend/www/assets/default-avatar.svg` (new) | Added static fallback avatar under asset path | Keeps defaults outside upload workflow |

## 3. Security controls implemented

### 3.1 Server-side validation and size controls

The upload is no longer trusted based on extension or browser-provided `Content-Type`.

Implemented checks:

- PHP upload error validation (`UPLOAD_ERR_*` handling).
- Empty file rejection.
- Max size check (`2MB` app-level limit).
- MIME detection using `finfo` / `mime_content_type` fallback.
- `getimagesize` validation for actual image parsing.
- Max dimension validation (`4096x4096`) to reduce parser abuse and oversized payload risk.

### 3.2 Content normalization (CDR-style image rewrite)

Accepted images are decoded and re-encoded to PNG via GD before storage. This strips unsupported/hostile payload structures that rely on preserving original binary content.

### 3.3 Storage isolation

Avatar storage moved to a private path outside web root:

- Default: `../private/avatars` (relative to app root) via `AVATAR_STORAGE_DIR`.
- Deployment path: `/var/www/private/avatars`.

Files are written with restrictive permissions (`0640` file, `0750` directory).

### 3.4 Controlled retrieval endpoint

`/avatar.php` now mediates avatar access:

- Requires authenticated session.
- Enforces that `?u=` matches the currently logged-in user.
- Returns fixed `Content-Type: image/png` and `X-Content-Type-Options: nosniff`.

This removes direct serving of untrusted upload files from web root.

### 3.5 CSRF protection

Upload POST now requires a session-bound CSRF token (`avatar_csrf_token`) with `hash_equals` verification.

### 3.6 Deployment hardening

`frontend/setup_frontend.sh` now:

- Uses secure private avatar directory.
- Reduces `upload_max_filesize` and `post_max_size`.
- Disables directory indexing in Apache docroot.
- Avoids world-writable upload directories.

## 4. OWASP Top 10 mapping (2021)

| OWASP category | Why it applied here | What changed |
|---|---|---|
| **A01: Broken Access Control** | Upload and file retrieval can become IDOR/authorization issues when file identifiers are exposed or unrestricted | Avatar retrieval now checks session ownership (`avatar.php` enforces requested user id == logged-in user id); CSRF token added for state-changing upload action |
| **A03: Injection** | Uploading attacker-controlled payloads that are later interpreted is an injection/RCE pathway | Non-image payloads are blocked by MIME + parser checks; image bytes are rewritten before storage; files are not executed from web root |
| **A04: Insecure Design** | Original design relied on extension checks and predictable web-root storage | Replaced with layered design: validation, rewrite, isolated storage, controlled retrieval |
| **A05: Security Misconfiguration** | World-writable directories, permissive execution context, and directory listing increased exploitability | Hardened filesystem permissions, removed insecure upload storage model, disabled docroot indexing, added `.htaccess` guardrail in legacy upload dir |
| **A08: Software and Data Integrity Failures** | Trusting raw user file bytes without integrity controls creates integrity-risk ingestion | Upload content is normalized via decode/re-encode before persistence; only known-safe image types are accepted |

## 5. CVE analysis and relevance

The following CVEs were used as reference cases to anchor risk and remediation decisions.

### CVE-2018-9206 (Blueimp jQuery File Upload)

- NVD describes this as an **unauthenticated arbitrary file upload vulnerability** in affected versions of jQuery File Upload.
- NVD maps it to **CWE-434 (Unrestricted Upload of File with Dangerous Type)**.
- Relevance: this is the exact failure class we addressed. Any extension-only upload control can collapse into arbitrary file upload if server-side controls are weak.
- Mitigation linkage in this codebase: strict server-side validation, binary rewrite, and non-web-root storage.

### CVE-2023-50164 (Apache Struts)

- NVD states attackers can manipulate upload parameters for path traversal, potentially resulting in malicious upload and remote code execution.
- NVD lists a **CVSS 3.1 score of 9.8 (Critical)**.
- Relevance: demonstrates that upload parameter handling and path resolution are high-value attack surfaces even in mature frameworks.
- Mitigation linkage: storage path is now application-controlled (`getAvatarStoragePath`), user input does not drive filesystem path construction.

### CVE-2024-53677 (Apache Struts)

- NVD and Apache S2-067 indicate flawed upload logic allowing traversal and possible RCE if not migrated to the new upload mechanism.
- NVD lists **CVSS 3.1 score 9.8 (Critical)**.
- Relevance: reinforces that partial upload fixes can be bypassed when architecture still trusts dangerous upload primitives.
- Mitigation linkage: this remediation changed architecture, not just regex checks, by introducing isolated storage + controlled serving.

### CVE-2021-22204 (ExifTool parsing issue)

- NVD describes improper neutralization in DjVu handling that allows code execution when parsing a malicious image.
- Relevance: even "valid image files" can exploit parser chains.
- Mitigation linkage: image validation is layered and includes rewriting, reducing raw payload survivability and limiting parser exposure.

### CVE-2016-3714 (ImageTragick)

- NVD describes crafted image input leading to command execution in vulnerable ImageMagick coders.
- NVD indicates this CVE is in CISA’s Known Exploited Vulnerabilities (KEV) catalog.
- Relevance: file upload risk is not only file extension abuse; parser exploitability is a long-lived operational risk.
- Mitigation linkage: strict upload constraints + conservative processing path + recommendation to keep parser libraries patched.

## 6. Validation checklist (manual)

Run these tests after deployment.

1. Positive test: upload a normal `jpg/png/webp` image smaller than 2MB.  
Expected: upload succeeds; avatar renders from `/avatar.php?u=<id>`.
2. Negative test: upload `shell.php` or `shell.php.jpg`.  
Expected: rejected with validation error.
3. Negative test: upload a text file renamed to `.jpg`.  
Expected: rejected as invalid image.
4. Negative test: upload image larger than 2MB.  
Expected: rejected for size.
5. Authorization test: request `/avatar.php?u=<different_user_id>` while logged in.  
Expected: HTTP 403.
6. Session test: submit profile upload form without valid CSRF token.  
Expected: rejected.
7. Filesystem test: verify avatar files are in private directory (`/var/www/private/avatars`) with non-executable permissions.

## 7. Remaining risk and recommendations

This fix closes the primary unrestricted file upload/RCE path. Residual risk still exists if operational hygiene is weak.

Recommended next controls:

1. Add antivirus or sandbox scanning for uploaded files.
2. Add explicit upload rate limiting and per-user quota.
3. Add security logging for rejected upload attempts (including source IP and reason code).
4. Keep GD/Image libraries patched in OS lifecycle updates.
5. Add automated security tests in CI for upload abuse cases.

## 8. Sources

- OWASP File Upload Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html
- OWASP Top 10 2021 A01: https://owasp.org/Top10/2021/A01_2021-Broken_Access_Control/
- OWASP Top 10 2021 A03: https://owasp.org/Top10/2021/A03_2021-Injection/
- OWASP Top 10 2021 A04: https://owasp.org/Top10/2021/A04_2021-Insecure_Design/
- OWASP Top 10 2021 A05: https://owasp.org/Top10/2021/A05_2021-Security_Misconfiguration/
- OWASP Top 10 2021 A08: https://owasp.org/Top10/2021/A08_2021-Software_and_Data_Integrity_Failures/
- NVD CVE-2018-9206: https://nvd.nist.gov/vuln/detail/CVE-2018-9206
- NVD CVE-2021-22204: https://nvd.nist.gov/vuln/detail/CVE-2021-22204
- NVD CVE-2023-50164: https://nvd.nist.gov/vuln/detail/CVE-2023-50164
- NVD CVE-2024-53677: https://nvd.nist.gov/vuln/detail/CVE-2024-53677
- NVD CVE-2016-3714: https://nvd.nist.gov/vuln/detail/CVE-2016-3714
- Apache Struts S2-066 bulletin: https://cwiki.apache.org/confluence/display/WW/S2-066
- Apache Struts S2-067 bulletin: https://cwiki.apache.org/confluence/display/WW/S2-067
