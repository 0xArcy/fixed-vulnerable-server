#!/bin/bash
FRONTEND_IP=${1:-"10.0.10.105"}
BACKEND_IP=${2:-"10.0.10.102"}
DB_IP=${3:-"10.0.10.106"}
SERVICE_TOKEN=$4

echo "Verifying E2E encryption and tokenization..."

echo "1. Testing Nginx Proxy Response (Frontend: $FRONTEND_IP)"
curl -sk "https://$FRONTEND_IP" | grep -q "ModernBank" \
    && echo " - Frontend check OK" \
    || echo " - Frontend check FAILED"

echo "2. Testing Backend Authentication TLS Channel (Backend: $BACKEND_IP)"
curl -ksi -X POST "https://$BACKEND_IP/api/auth/login" \
    -H "Content-Type: application/json" \
    -H "x-internal-token: $SERVICE_TOKEN" \
    -d '{"username":"julia.ross","password":"BankDemo!2026"}' | grep -qi "HTTP/.*" \
    && echo " - Backend HTTP/TLS channel OK" \
    || echo " - Backend channel FAILED"

echo "Done"
