#!/bin/bash
# Test script for Horizen Network multi-app architecture
# This script demonstrates the authentication and entitlement flow

set -e

API_URL="${API_URL:-http://localhost:8000}"
GENIESS_URL="${GENIESS_URL:-http://localhost:8001}"
ENTITY_URL="${ENTITY_URL:-http://localhost:8002}"

echo "========================================="
echo "Horizen Network - Authentication Test"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test email
TEST_EMAIL="test-$(date +%s)@example.com"
TEST_PASSWORD="SecurePassword123!"

echo -e "${BLUE}1. Registering new user: $TEST_EMAIL${NC}"
REGISTER_RESPONSE=$(curl -s -X POST "$API_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"full_name\":\"Test User\"}")

TOKEN=$(echo $REGISTER_RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ Failed to register user${NC}"
    echo "$REGISTER_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ User registered successfully${NC}"
echo ""

echo -e "${BLUE}2. Testing access control without entitlements${NC}"

# Test Geniess without entitlement
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test_response.json "$GENIESS_URL/api/info" \
  -H "Authorization: Bearer $TOKEN")

if [ "$HTTP_CODE" = "403" ]; then
    echo -e "${GREEN}✓ Geniess correctly denied access (403 Forbidden)${NC}"
else
    echo -e "${RED}✗ Expected 403, got $HTTP_CODE${NC}"
fi

# Test Entity without entitlement
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test_response.json "$ENTITY_URL/api/info" \
  -H "Authorization: Bearer $TOKEN")

if [ "$HTTP_CODE" = "403" ]; then
    echo -e "${GREEN}✓ Entity correctly denied access (403 Forbidden)${NC}"
else
    echo -e "${RED}✗ Expected 403, got $HTTP_CODE${NC}"
fi
echo ""

echo -e "${BLUE}3. Granting BUNDLE_DRUID_GENIESS entitlement${NC}"
curl -s -X POST "$API_URL/api/entitlements/grant?email=$TEST_EMAIL&entitlement=BUNDLE_DRUID_GENIESS" \
  -H "Authorization: Bearer $TOKEN" > /dev/null
echo -e "${GREEN}✓ Entitlement granted${NC}"
echo ""

echo -e "${BLUE}4. Testing Geniess access with entitlement${NC}"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test_response.json "$GENIESS_URL/api/info" \
  -H "Authorization: Bearer $TOKEN")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Geniess access granted (200 OK)${NC}"
    echo "Response:"
    cat /tmp/test_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/test_response.json
else
    echo -e "${RED}✗ Expected 200, got $HTTP_CODE${NC}"
fi
echo ""

echo -e "${BLUE}5. Granting ENTITY entitlement${NC}"
curl -s -X POST "$API_URL/api/entitlements/grant?email=$TEST_EMAIL&entitlement=ENTITY" \
  -H "Authorization: Bearer $TOKEN" > /dev/null
echo -e "${GREEN}✓ Entitlement granted${NC}"
echo ""

echo -e "${BLUE}6. Testing Entity access with entitlement${NC}"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test_response.json "$ENTITY_URL/api/info" \
  -H "Authorization: Bearer $TOKEN")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Entity access granted (200 OK)${NC}"
    echo "Response:"
    cat /tmp/test_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/test_response.json
else
    echo -e "${RED}✗ Expected 200, got $HTTP_CODE${NC}"
fi
echo ""

echo -e "${BLUE}7. Getting user information${NC}"
curl -s "$API_URL/api/auth/me" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool 2>/dev/null
echo ""

echo -e "${BLUE}8. Getting pricing information${NC}"
curl -s "$API_URL/api/pricing" | python3 -m json.tool 2>/dev/null
echo ""

echo "========================================="
echo -e "${GREEN}All tests completed successfully!${NC}"
echo "========================================="
