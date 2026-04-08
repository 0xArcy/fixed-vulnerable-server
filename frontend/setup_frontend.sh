#!/bin/bash
##############################################################################
# Modern Bank - Secure Frontend Setup (Nginx "godproxy" TLS edge)
# Usage: sudo ./setup_frontend.sh <BACKEND_IP> [INTERNAL_API_TOKEN]
##############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKEND_IP="${1:-10.0.10.102}"
INTERNAL_API_TOKEN="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/var/www/modernbank-app"
TLS_CERT_PATH="/etc/ssl/certs/modernbank-frontend.crt"
TLS_KEY_PATH="/etc/ssl/private/modernbank-frontend.key"
NGINX_SITE_PATH="/etc/nginx/sites-available/modernbank-godproxy.conf"
LOG_FILE="/var/log/modern_bank_frontend_setup.log"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Run this script as root." >&2
    exit 1
fi

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"
}

trap 'error "Setup failed at line $LINENO while running: $BASH_COMMAND"' ERR

if [[ -z "$INTERNAL_API_TOKEN" ]]; then
    INTERNAL_API_TOKEN="$(openssl rand -hex 24)"
    warn "No INTERNAL_API_TOKEN provided. Generated one automatically."
    warn "Use the same token value for backend/setup_backend.sh argument #3."
fi

FRONTEND_IP="$(hostname -I | awk '{print $1}')"
if [[ -z "$FRONTEND_IP" ]]; then
    error "Unable to determine frontend IP from hostname -I"
fi

log "Starting secure frontend setup"
log "Frontend IP: $FRONTEND_IP"
log "Backend IP: $BACKEND_IP"

log "Installing dependencies"
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq nginx openssl curl ca-certificates ufw

log "Deploying JavaScript frontend"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -a "$SCRIPT_DIR/app/." "$APP_DIR/"
chown -R www-data:www-data "$APP_DIR"
find "$APP_DIR" -type f -exec chmod 644 {} \;
find "$APP_DIR" -type d -exec chmod 755 {} \;

log "Generating TLS certificate for frontend edge"
mkdir -p "$(dirname "$TLS_CERT_PATH")" "$(dirname "$TLS_KEY_PATH")"
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 825 \
    -keyout "$TLS_KEY_PATH" \
    -out "$TLS_CERT_PATH" \
    -subj "/C=US/ST=Ontario/L=Toronto/O=Modern Bank/CN=modernbank-frontend" \
    -addext "subjectAltName=IP:${FRONTEND_IP},IP:127.0.0.1,DNS:modernbank-frontend.local" \
    >/dev/null 2>&1

chmod 600 "$TLS_KEY_PATH"
chmod 644 "$TLS_CERT_PATH"

log "Writing Nginx godproxy configuration"
cat > "$NGINX_SITE_PATH" <<NGINXCONF
limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=15r/s;

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;

    ssl_certificate ${TLS_CERT_PATH};
    ssl_certificate_key ${TLS_KEY_PATH};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    root ${APP_DIR};
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        limit_req zone=api_limit burst=25 nodelay;

        proxy_pass https://${BACKEND_IP}:8443;
        proxy_http_version 1.1;
        proxy_ssl_server_name on;
        proxy_ssl_verify off;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Internal-Token ${INTERNAL_API_TOKEN};

        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
    }
}
NGINXCONF

rm -f /etc/nginx/sites-enabled/default
ln -sf "$NGINX_SITE_PATH" /etc/nginx/sites-enabled/modernbank-godproxy.conf

nginx -t
systemctl enable nginx
systemctl restart nginx

log "Configuring firewall"
ufw allow 22/tcp >/dev/null 2>&1 || true
ufw allow 80/tcp >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

log "Running local validation checks"
if curl -ks --max-time 5 "https://127.0.0.1/" | grep -q "Modern Bank"; then
    success "Frontend UI is reachable over TLS"
else
    warn "Could not verify frontend HTML response locally"
fi

if curl -ks --max-time 5 "https://127.0.0.1/api/health" | grep -q '"status":"ok"'; then
    success "Frontend-to-backend TLS proxy path is active"
else
    warn "API proxy health check did not return expected payload"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Secure Frontend Setup Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Frontend URL: ${BLUE}https://${FRONTEND_IP}${NC}"
echo -e "Backend target: ${BLUE}https://${BACKEND_IP}:8443${NC}"
echo -e "Shared internal token: ${BLUE}${INTERNAL_API_TOKEN}${NC}"
echo ""

success "Frontend tier is configured for encrypted-by-default traffic."
