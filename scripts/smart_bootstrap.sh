#!/bin/bash

# Smart Bootstrap - Checks for existing data/backups before expensive operations
# Uses Supabase Storage for backups instead of local files

set -e

# Load environment variables from .env if it exists
if [ -f .env ]; then
  echo "📄 Loading environment from .env file..."
  export $(grep -v '^#' .env | xargs)
fi

SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
ADMIN_EMAIL="${ADMIN_EMAIL:-jc@alloatech.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-monkey}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 rem_mm Smart Bootstrap${NC}"
echo "============================"
echo ""

# Get JWT token
echo -e "${GREEN}🔐 Authenticating...${NC}"
if [ -z "$JWT_TOKEN" ]; then
  # Use Supabase auth API directly with anon key
  SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH}"
  
  AUTH_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")
  
  JWT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token')
  
  if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" == "null" ]; then
    echo -e "${RED}❌ Failed to authenticate${NC}"
    echo "Response: $AUTH_RESPONSE"
    echo "Credentials: email=$ADMIN_EMAIL"
    exit 1
  fi
fi
echo -e "${GREEN}✅ Authenticated as $ADMIN_EMAIL (super_admin)${NC}"

# Step 1: Check existing data
echo -e "\n${GREEN}🔍 Step 1: Checking existing data...${NC}"
CHECK_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"check_existing_data"}')

echo "$CHECK_RESPONSE" | jq '.'

HAS_PLAYERS=$(echo "$CHECK_RESPONSE" | jq -r '.data.players.exists')
HAS_EMBEDDINGS=$(echo "$CHECK_RESPONSE" | jq -r '.data.embeddings.exists')
HAS_BACKUPS=$(echo "$CHECK_RESPONSE" | jq -r '.data.backups.available')
RECOMMENDATION=$(echo "$CHECK_RESPONSE" | jq -r '.recommendation')

echo -e "\n${BLUE}📊 Current State:${NC}"
echo -e "  Players:    $(echo "$CHECK_RESPONSE" | jq -r '.data.players.count')"
echo -e "  Embeddings: $(echo "$CHECK_RESPONSE" | jq -r '.data.embeddings.count')"
echo -e "  Backups:    $(echo "$CHECK_RESPONSE" | jq -r '.data.backups.count')"
echo -e "\n${YELLOW}💡 Recommendation: $RECOMMENDATION${NC}"

# Step 2: Get smart bootstrap plan
echo -e "\n${GREEN}📋 Step 2: Creating bootstrap plan...${NC}"

# Ask for Gemini key if needed
GEMINI_PARAM=""
if [ "$HAS_EMBEDDINGS" != "true" ] && [ "$HAS_BACKUPS" != "true" ]; then
  if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  Embeddings will be needed. Set GEMINI_API_KEY to include them.${NC}"
    read -p "Enter Gemini API key (or press Enter to skip embeddings): " GEMINI_INPUT
    if [ -n "$GEMINI_INPUT" ]; then
      GEMINI_API_KEY="$GEMINI_INPUT"
    fi
  fi
  
  if [ -n "$GEMINI_API_KEY" ]; then
    GEMINI_PARAM=",\"gemini_api_key\":\"$GEMINI_API_KEY\""
  fi
fi

PLAN_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"smart_bootstrap\"$GEMINI_PARAM}")

echo "$PLAN_RESPONSE" | jq '.plan'

ESTIMATED_COST=$(echo "$PLAN_RESPONSE" | jq -r '.estimated_cost')
ESTIMATED_TIME=$(echo "$PLAN_RESPONSE" | jq -r '.estimated_time_seconds')

echo -e "\n${BLUE}💰 Estimated Cost: \$$ESTIMATED_COST${NC}"
echo -e "${BLUE}⏱️  Estimated Time: ${ESTIMATED_TIME}s ($(($ESTIMATED_TIME / 60)) min)${NC}"

# Step 3: Confirm and execute
echo ""
read -p "Execute this plan? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted. You can run this script again anytime."
  exit 0
fi

echo -e "\n${GREEN}▶️  Step 3: Executing bootstrap plan...${NC}"

PLAN_JSON=$(echo "$PLAN_RESPONSE" | jq -c '.plan')
EXECUTE_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"execute_bootstrap_plan\",\"data\":{\"plan\":$PLAN_JSON$GEMINI_PARAM}}")

echo "$EXECUTE_RESPONSE" | jq '.results'

# Check for failures
FAILURES=$(echo "$EXECUTE_RESPONSE" | jq '[.results[] | select(.success == false)] | length')
if [ "$FAILURES" -gt 0 ]; then
  echo -e "\n${RED}⚠️  $FAILURES step(s) failed. Check output above.${NC}"
else
  echo -e "\n${GREEN}✅ All steps completed successfully!${NC}"
fi

# Step 4: Final stats
echo -e "\n${GREEN}📊 Final Statistics:${NC}"
STATS=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"get_stats"}')

echo "$STATS" | jq '{
  players: {
    total: .players.totalPlayers,
    byPosition: .players.byPosition | to_entries | map({position: .key, count: .value}) | sort_by(-.count) | .[0:5],
    active: .players.activeCount
  },
  embeddings: {
    total: .embeddings.totalEmbedded,
    byReason: .embeddings.byReason
  }
}'

echo -e "\n${GREEN}✨ Bootstrap complete!${NC}"
echo ""
echo "Next steps:"
echo "  • Data is backed up in Supabase Storage"
echo "  • After 'supabase db reset', this script will auto-restore from backups"
echo "  • No more expensive Gemini API calls needed!"
echo "  • View backups: curl -X POST '$SUPABASE_URL/functions/v1/player-data-admin-v2' \\"
echo "      -H 'Authorization: Bearer \$JWT_TOKEN' \\"
echo "      -d '{\"action\":\"list_backups\"}'"
