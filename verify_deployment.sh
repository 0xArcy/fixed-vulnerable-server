#!/bin/bash
# Deployment verification for encrypted Modern Bank stack

set -euo pipefail

FRONTEND_IP="${1:-10.0.10.105}"
BACKEND_IP="${2:-10.0.10.102}"
DATABASE_IP="${3:-10.0.10.106}"
INTERNAL_API_TOKEN="${4:-}"

check_mark="[OK]"
cross_mark="[FAIL]"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}${check_mark}${NC} $1"
}

fail() {
    echo -e "${RED}${cross_mark}${NC} $1"
}

warn() {
    echo -e "${YELLOW}!${NC} $1"
}

echo "=================================================="
echo "Modern Bank Secure Stack - Deployment Verification"
echo "=================================================="
echo ""

echo "======== FRONTEND TLS EDGE (${FRONTEND_IP}) ========"

if ping -c 1 "$FRONTEND_IP" >/dev/null 2>&1; then
    pass "Frontend host is reachable"
else
    fail "Frontend host is unreachable"
    exit 1
fi

if nc -zw2 "$FRONTEND_IP" 443 >/dev/null 2>&1; then
    pass "TLS edge port 443 is listening"
else
    fail "TLS edge port 443 is not reachable"
fi

if curl -ks --max-time 6 "https://${FRONTEND_IP}/" | grep -q "Modern Bank"; then
    pass "Frontend UI responds over HTTPS"
else
    fail "Frontend UI does not respond correctly over HTTPS"
fi

if curl -sI --max-time 6 "http://${FRONTEND_IP}/" | grep -qi "301\|302"; then
    pass "HTTP is redirected to HTTPS"
else
    warn "HTTP redirect to HTTPS was not detected"
fi

echo ""
echo "======== API THROUGH GODPROXY ========"

if curl -ks --max-time 6 "https://${FRONTEND_IP}/api/health" | grep -q '"status":"ok"'; then
    pass "Frontend -> backend API path is healthy"
else
    fail "Frontend reverse proxy could not reach backend health endpoint"
fi

LOGIN_RESPONSE="$(curl -ks --max-time 8 \
    -X POST "https://${FRONTEND_IP}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"julia.ross","password":"BankDemo!2026"}')"

ACCESS_TOKEN="$(echo "$LOGIN_RESPONSE" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')"

if [[ -n "$ACCESS_TOKEN" ]]; then
    pass "JWT login works through TLS proxy"
else
    fail "JWT login failed through TLS proxy"
fi

if [[ -n "$ACCESS_TOKEN" ]]; then
    if curl -ks --max-time 8 \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        "https://${FRONTEND_IP}/api/db-status" | grep -q '"mongo_transport":"tls"'; then
        pass "Backend reports Mongo transport as TLS"
    else
        fail "Mongo TLS status check failed"
    fi

    if curl -ks --max-time 8 \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        "https://${FRONTEND_IP}/api/tokenization/example" | grep -q '"tokenized":"tok_'; then
        pass "Tokenization endpoint is active"
    else
        fail "Tokenization endpoint did not return expected token format"
    fi
fi

echo ""
echo "======== BACKEND DIRECT (${BACKEND_IP}:8443) ========"

if nc -zw2 "$BACKEND_IP" 8443 >/dev/null 2>&1; then
    pass "Backend TLS port 8443 is reachable"
else
    warn "Backend TLS port 8443 is not reachable from this verifier host (may be firewall policy)"
fi

DIRECT_STATUS="$(curl -ks --max-time 6 -o /dev/null -w "%{http_code}" "https://${BACKEND_IP}:8443/api/health" || true)"
if [[ "$DIRECT_STATUS" == "401" ]]; then
    pass "Backend rejects direct API requests without internal token"
elif [[ "$DIRECT_STATUS" == "000" ]]; then
    warn "Could not test direct backend auth gate from verifier host"
else
    warn "Unexpected direct backend /api/health status: ${DIRECT_STATUS}"
fi

if [[ -n "$INTERNAL_API_TOKEN" ]]; then
    TOKEN_STATUS="$(curl -ks --max-time 6 -o /dev/null -w "%{http_code}" \
        -H "X-Internal-Token: ${INTERNAL_API_TOKEN}" \
        "https://${BACKEND_IP}:8443/api/health" || true)"

    if [[ "$TOKEN_STATUS" == "200" ]]; then
        pass "Provided internal token can access backend directly"
    else
        warn "Provided internal token did not validate on direct backend path"
    fi
else
    warn "Internal token not provided to verifier; skipped direct token-auth test"
fi

echo ""
echo "======== DATABASE TIER (${DATABASE_IP}:27017) ========"

if ping -c 1 "$DATABASE_IP" >/dev/null 2>&1; then
    pass "Database host is reachable"
else
    fail "Database host is unreachable"
fi

if nc -zw2 "$DATABASE_IP" 27017 >/dev/null 2>&1; then
    pass "MongoDB TLS port 27017 is reachable"
else
    warn "MongoDB port 27017 is not reachable from this verifier host (may be backend-only firewall rule)"
fi

echo ""
echo "======== SUMMARY ========"
echo ""
echo "1. Frontend: HTTPS edge at https://${FRONTEND_IP}"
echo "2. Backend: HTTPS API at https://${BACKEND_IP}:8443 (service-token gated)"
echo "3. Database: MongoDB TLS at ${DATABASE_IP}:27017"
echo "4. User auth: JWT"
echo "5. Data protection: deterministic tokenization before persistence"
echo ""
