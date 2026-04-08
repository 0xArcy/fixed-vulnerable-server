#!/bin/bash
BACKEND_IP=${1:-"10.0.10.102"}
SERVICE_TOKEN=$2

echo "Setting up Frontend proxy stack (Ubuntu OS 10.0.10.105)..."
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

if [ -z "$SERVICE_TOKEN" ]; then
    echo "Usage: sudo bash setup_nginx_proxy.sh <BACKEND_IP> <SERVICE_TOKEN>"
    exit 1
fi

apt-get update
apt-get install -y nginx openssl ufw

# Secure Firewall
ufw allow 443/tcp
ufw allow 80/tcp
ufw --force enable

# Configure JS app
APP_DIR="/var/www/modernbank"
mkdir -p $APP_DIR
cp -r $(dirname "$0")/app/* $APP_DIR/ || echo "Warning: could not copy frontend app files. Assuming they exist."

# Inject service token and API conditionally if app.js exists
if [ -f "$APP_DIR/app.js" ]; then
  sed -i "s/INSERT_SERVICE_TOKEN/$SERVICE_TOKEN/g" $APP_DIR/app.js
  sed -i "s/10.0.10.102/$BACKEND_IP/g" $APP_DIR/app.js
fi

# Generate Frontend TLS 
mkdir -p /etc/ssl/modernbank
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/modernbank/frontend.key \
    -out /etc/ssl/modernbank/frontend.crt \
    -subj "/CN=10.0.10.105"
chmod 600 /etc/ssl/modernbank/frontend.key

# NGINX Conf
cat <<CONF > /etc/nginx/sites-available/default
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri; # Redirect all HTTP to HTTPS
}

server {
    listen 443 ssl http2;
    server_name _;

    ssl_certificate /etc/ssl/modernbank/frontend.crt;
    ssl_certificate_key /etc/ssl/modernbank/frontend.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root $APP_DIR;
    index index.html;

    location /api/ {
        proxy_pass https://$BACKEND_IP/;
        proxy_ssl_verify off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Service-Token "$SERVICE_TOKEN";
    }

    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Hardened Security Headers against OWASP Top 10 vulnerabilities
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Content-Type-Options "nosniff";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self'; connect-src 'self' https://$BACKEND_IP;";
        add_header Referrer-Policy "strict-origin-when-cross-origin";
    }
}
CONF

systemctl restart nginx
systemctl enable nginx

echo "Frontend secure godproxy TLS mapping complete on 10.0.10.105 with Nginx."
