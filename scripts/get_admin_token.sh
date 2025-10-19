#!/bin/bash

# Helper script to get admin JWT token
# Usage: export JWT_TOKEN=$(./scripts/get_admin_token.sh)

SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"

# Load from .env if available
if [ -f .env ]; then
  export $(grep -v '^#' .env | grep -E '(ADMIN_EMAIL|ADMIN_PASSWORD)' | xargs)
fi

ADMIN_EMAIL="${ADMIN_EMAIL:-jc@alloatech.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-monkey}"

# Get token from get-auth-token function
AUTH_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/get-auth-token" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")

JWT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth_data.access_token')

if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" == "null" ]; then
  echo "ERROR: Failed to get token" >&2
  echo "Response: $AUTH_RESPONSE" >&2
  exit 1
fi

echo "$JWT_TOKEN"
