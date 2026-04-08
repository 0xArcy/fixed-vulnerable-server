#!/bin/bash
##############################################################################
# Modern Bank - Secure Backend Setup (Ubuntu Server)
# Usage: sudo ./setup_backend.sh <FRONTEND_IP> <DATABASE_IP> [INTERNAL_API_TOKEN]
##############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FRONTEND_IP="${1:-10.0.10.105}"
DATABASE_IP="${2:-10.0.10.106}"
INTERNAL_API_TOKEN="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="/opt/modernbank-backend"
SERVICE_NAME="modernbank-backend"
LOG_FILE="/var/log/modern_bank_backend_setup.log"
BACKEND_PORT="8443"

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
fi

MONGO_DB_NAME="${MONGO_DB_NAME:-modernbank}"
MONGO_APP_USER="${MONGO_APP_USER:-modernbank_app}"
MONGO_APP_PASSWORD="${MONGO_APP_PASSWORD:-ModernBankMongo!2026}"
MONGO_TLS_CA_FILE="${MONGO_TLS_CA_FILE:-}"
MONGO_TLS_ALLOW_INVALID_CERTS="${MONGO_TLS_ALLOW_INVALID_CERTS:-true}"

JWT_SECRET="$(openssl rand -hex 32)"
TOKENIZATION_KEY="$(openssl rand -hex 32)"

BACKEND_BIND_IP="$(hostname -I | awk '{print $1}')"
if [[ -z "$BACKEND_BIND_IP" ]]; then
    error "Unable to determine backend bind IP."
fi

log "Starting secure backend setup"
log "Frontend IP: $FRONTEND_IP"
log "Database IP: $DATABASE_IP"
log "Backend bind IP: $BACKEND_BIND_IP"

log "Installing dependencies"
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq curl wget git openssl ca-certificates ufw build-essential python3

if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
    apt-get install -y -qq nodejs
fi

log "Node: $(node --version)"
log "NPM: $(npm --version)"

log "Deploying backend files"
mkdir -p "$API_DIR"
cp -a "$SCRIPT_DIR/api/." "$API_DIR/"

if [[ ! -f "$API_DIR/package.json" || ! -f "$API_DIR/server.js" ]]; then
    error "Backend source files were not copied correctly."
fi

log "Installing backend npm dependencies"
cd "$API_DIR"
npm install --omit=dev --no-audit --no-fund >> "$LOG_FILE" 2>&1

log "Generating backend TLS certificate"
mkdir -p "$API_DIR/certs"
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 825 \
    -keyout "$API_DIR/certs/backend.key" \
    -out "$API_DIR/certs/backend.crt" \
    -subj "/C=US/ST=Ontario/L=Toronto/O=Modern Bank/CN=modernbank-backend" \
    -addext "subjectAltName=IP:${BACKEND_BIND_IP},IP:127.0.0.1,DNS:modernbank-backend.local" \
    >/dev/null 2>&1

chmod 640 "$API_DIR/certs/backend.key"
chmod 644 "$API_DIR/certs/backend.crt"

ENCODED_DB_USER="$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$MONGO_APP_USER")"
ENCODED_DB_PASS="$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$MONGO_APP_PASSWORD")"
MONGO_URI="mongodb://${ENCODED_DB_USER}:${ENCODED_DB_PASS}@${DATABASE_IP}:27017/${MONGO_DB_NAME}?authSource=admin&tls=true"

log "Writing backend environment file"
cat > "$API_DIR/.env" <<ENVVARS
NODE_ENV=production
PORT=${BACKEND_PORT}
TLS_CERT_PATH=${API_DIR}/certs/backend.crt
TLS_KEY_PATH=${API_DIR}/certs/backend.key
FRONTEND_ORIGIN=https://${FRONTEND_IP}
INTERNAL_API_TOKEN=${INTERNAL_API_TOKEN}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=30m
TOKENIZATION_KEY=${TOKENIZATION_KEY}
MONGO_URI=${MONGO_URI}
MONGO_MAX_POOL_SIZE=10
MONGO_TLS_CA_FILE=${MONGO_TLS_CA_FILE}
MONGO_TLS_ALLOW_INVALID_CERTS=${MONGO_TLS_ALLOW_INVALID_CERTS}
DEMO_USERNAME=julia.ross
DEMO_PASSWORD=BankDemo!2026
DEMO_USER_ID=1001
ENVVARS

chmod 640 "$API_DIR/.env"

if ! id -u modernbank >/dev/null 2>&1; then
    useradd --system --home "$API_DIR" --shell /usr/sbin/nologin modernbank
fi

chown -R modernbank:modernbank "$API_DIR"

log "Creating systemd service"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SERVICE
[Unit]
Description=Modern Bank Secure Backend API
After=network.target

[Service]
Type=simple
User=modernbank
Group=modernbank
WorkingDirectory=${API_DIR}
ExecStart=/usr/bin/node ${API_DIR}/server.js
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=${API_DIR}

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    journalctl -u "$SERVICE_NAME" -n 80 --no-pager >&2
    error "Backend service failed to start."
fi

log "Applying firewall rules"
ufw allow 22/tcp >/dev/null 2>&1 || true
ufw allow from "$FRONTEND_IP" to any port "$BACKEND_PORT" proto tcp >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

log "Running local backend health test"
if curl -ks --max-time 5 \
    -H "X-Internal-Token: ${INTERNAL_API_TOKEN}" \
    "https://127.0.0.1:${BACKEND_PORT}/api/health" | grep -q '"status":"ok"'; then
    success "Secure backend health endpoint responded over TLS"
else
    warn "Backend health check did not return expected payload."
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Secure Backend Setup Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Backend HTTPS URL: ${BLUE}https://${BACKEND_BIND_IP}:${BACKEND_PORT}${NC}"
echo -e "Frontend Origin: ${BLUE}https://${FRONTEND_IP}${NC}"
echo -e "MongoDB Host: ${BLUE}${DATABASE_IP}:27017 (TLS required)${NC}"
echo -e "Internal API Token: ${BLUE}${INTERNAL_API_TOKEN}${NC}"
echo ""
echo "Pass this same token to frontend/setup_frontend.sh as argument #2."
echo ""

success "Backend tier is configured for encrypted service-to-service communication."
