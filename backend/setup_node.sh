#!/bin/bash
FRONTEND_IP=${1:-"10.0.10.105"}
DB_IP=${2:-"10.0.10.106"}
SERVICE_TOKEN=${3:-$(openssl rand -hex 24)}

echo "Setting up Backend (Ubuntu Server 10.0.10.102)..."

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

apt-get update
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs build-essential openssl ufw pm2

# Setup Firewall
ufw allow 443/tcp
ufw allow from $FRONTEND_IP to any port 443
ufw --force enable

# Generate TLS certs for backend
mkdir -p /etc/ssl/modernbank
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/modernbank/backend.key \
    -out /etc/ssl/modernbank/backend.crt \
    -subj "/CN=10.0.10.102"
chmod 600 /etc/ssl/modernbank/backend.key

# Prepare codebase
cd /opt/backend/api 2>/dev/null || cd $(dirname "$0")/api
if [ ! -f package.json ]; then
    echo "Creating package.json natively..."
    cat <<PACKAGE > package.json
{
  "name": "modernbank-api",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.0.3",
    "jsonwebtoken": "^9.0.0",
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "helmet": "^6.1.5"
  }
}
PACKAGE
fi

npm install
npm install pm2 -g

# Create environment file
DB_USER=modernbank_app
DB_PASS=ModernBankMongo\!2026
cat <<ENV > .env
MONGO_URI=mongodb://$DB_USER:$DB_PASS@$DB_IP:27017/bank?tls=true
JWT_SECRET=$(openssl rand -base64 32)
INTERNAL_API_TOKEN=$SERVICE_TOKEN
TOKENIZATION_KEY=$(openssl rand -base64 32)
TLS_CERT_PATH=/etc/ssl/modernbank/backend.crt
TLS_KEY_PATH=/etc/ssl/modernbank/backend.key
FRONTEND_ORIGIN=https://$FRONTEND_IP
MONGO_TLS_ALLOW_INVALID_CERTS=true
PORT=443
ENV

# Start app via pm2
pm2 start server.js --name "modernbank-api" -f
pm2 startup
pm2 save

echo "Backend configured securely on 10.0.10.102."
echo "SERVICE_TOKEN=$SERVICE_TOKEN"
