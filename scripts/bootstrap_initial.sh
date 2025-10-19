#!/bin/bash

# Initial bootstrap script - sets up player data from scratch
# Run this once after initial deployment or db reset

set -e

SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 rem_mm Initial Bootstrap${NC}"
echo "============================="
echo ""
echo "This script will:"
echo "  1. Fetch all NFL players from Sleeper API"
echo "  2. Store them in players_raw table"
echo "  3. Create selective embeddings for ~500 key players"
echo "  4. Export backups for quick restore"
echo ""

# Check for Gemini API key
if [ -z "$GEMINI_API_KEY" ]; then
  echo -e "${RED}❌ GEMINI_API_KEY not set${NC}"
  echo "   Please set it: export GEMINI_API_KEY=your_key_here"
  exit 1
fi

# Get JWT token
echo -e "${GREEN}🔐 Authenticating...${NC}"
if [ -z "$JWT_TOKEN" ]; then
  JWT_TOKEN=$(curl -s -X POST 'http://127.0.0.1:54321/auth/v1/token?grant_type=password' \
    -H 'apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' \
    -H 'Content-Type: application/json' \
    -d '{"email":"jc@alloatech.com","password":"monkey"}' | jq -r '.access_token')
  
  if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" == "null" ]; then
    echo -e "${RED}❌ Failed to authenticate${NC}"
    exit 1
  fi
fi
echo -e "${GREEN}✅ Authenticated${NC}"

# Step 1: Fetch players from Sleeper
echo -e "\n${GREEN}📥 Step 1: Fetching players from Sleeper API...${NC}"
RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"fetch_sleeper_data"}')

if echo "$RESPONSE" | jq -e '.success' > /dev/null; then
  TOTAL=$(echo "$RESPONSE" | jq -r '.totalFetched')
  FANTASY=$(echo "$RESPONSE" | jq -r '.fantasyRelevant')
  echo -e "${GREEN}✅ Fetched $TOTAL total players, stored $FANTASY fantasy-relevant${NC}"
else
  echo -e "${RED}❌ Failed to fetch players${NC}"
  echo "$RESPONSE" | jq '.'
  exit 1
fi

# Step 2: Create embeddings
echo -e "\n${GREEN}🤖 Step 2: Creating selective embeddings...${NC}"
echo -e "${YELLOW}⏳ This will take 2-5 minutes and cost ~\$0.50 in Gemini API calls${NC}"
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping embeddings. You can create them later with:"
  echo "  curl -X POST '$SUPABASE_URL/functions/v1/simple-ingestion' \\"
  echo "    -H 'Authorization: Bearer \$JWT_TOKEN' \\"
  echo "    -d '{\"limit\":500,\"gemini_api_key\":\"YOUR_KEY\"}'"
  exit 0
fi

RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/simple-ingestion" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"limit\":500,\"test_mode\":false,\"gemini_api_key\":\"$GEMINI_API_KEY\"}")

if echo "$RESPONSE" | jq -e '.success' > /dev/null; then
  EMBEDDED=$(echo "$RESPONSE" | jq -r '.embedded_count')
  echo -e "${GREEN}✅ Created $EMBEDDED embeddings${NC}"
else
  echo -e "${RED}❌ Failed to create embeddings${NC}"
  echo "$RESPONSE" | jq '.'
  exit 1
fi

# Step 3: Create backups
echo -e "\n${GREEN}💾 Step 3: Creating backups...${NC}"
./scripts/backup_player_data.sh

# Final stats
echo -e "\n${GREEN}📊 Final Statistics:${NC}"
STATS=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"get_stats"}')

echo "$STATS" | jq '{
  players: {
    total: .players.totalPlayers,
    byPosition: .players.byPosition,
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
echo "  • Backups saved to ./backups/ for quick restore"
echo "  • After 'supabase db reset', run: ./scripts/restore_player_data.sh"
echo "  • Set up daily cron: UPDATE players once per day"
echo "  • Monitor costs: Only embed new players as needed"
