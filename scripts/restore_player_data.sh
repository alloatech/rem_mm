#!/bin/bash

# Quick restore script for development
# Restores player data and embeddings from backup files

set -e

BACKUP_DIR="./backups"
SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔄 rem_mm Player Data Restore${NC}"
echo "================================"

# Check if JWT token is provided
if [ -z "$JWT_TOKEN" ]; then
  echo -e "${YELLOW}⚠️  JWT_TOKEN not set. Please run:${NC}"
  echo "   export JWT_TOKEN=\$(curl -X POST 'http://127.0.0.1:54321/auth/v1/token?grant_type=password' \\"
  echo "     -H 'apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' \\"
  echo "     -H 'Content-Type: application/json' \\"
  echo "     -d '{\"email\":\"jc@alloatech.com\",\"password\":\"monkey\"}' | jq -r '.access_token')"
  exit 1
fi

# Check for backup files
PLAYERS_FILE="$BACKUP_DIR/players_latest.json"
EMBEDDINGS_FILE="$BACKUP_DIR/embeddings_latest.json"

if [ ! -f "$PLAYERS_FILE" ]; then
  echo -e "${RED}❌ Players backup not found: $PLAYERS_FILE${NC}"
  echo "   Run: ./scripts/backup_player_data.sh first"
  exit 1
fi

if [ ! -f "$EMBEDDINGS_FILE" ]; then
  echo -e "${YELLOW}⚠️  Embeddings backup not found: $EMBEDDINGS_FILE${NC}"
  echo "   Will skip embeddings restore"
  SKIP_EMBEDDINGS=true
fi

# Restore players
echo -e "\n${GREEN}📥 Restoring players...${NC}"
PLAYERS_DATA=$(cat "$PLAYERS_FILE" | jq '.data')
PLAYER_COUNT=$(echo "$PLAYERS_DATA" | jq 'length')
echo "   Found $PLAYER_COUNT players in backup"

RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"import_players\",\"data\":$PLAYERS_DATA}")

if echo "$RESPONSE" | jq -e '.success' > /dev/null; then
  IMPORTED=$(echo "$RESPONSE" | jq -r '.imported')
  echo -e "${GREEN}✅ Successfully restored $IMPORTED players${NC}"
else
  echo -e "${RED}❌ Failed to restore players${NC}"
  echo "$RESPONSE" | jq '.'
  exit 1
fi

# Restore embeddings
if [ "$SKIP_EMBEDDINGS" != "true" ]; then
  echo -e "\n${GREEN}📥 Restoring embeddings...${NC}"
  EMBEDDINGS_DATA=$(cat "$EMBEDDINGS_FILE" | jq '.data')
  EMBEDDING_COUNT=$(echo "$EMBEDDINGS_DATA" | jq 'length')
  echo "   Found $EMBEDDING_COUNT embeddings in backup"

  RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"action\":\"import_embeddings\",\"data\":$EMBEDDINGS_DATA}")

  if echo "$RESPONSE" | jq -e '.success' > /dev/null; then
    IMPORTED=$(echo "$RESPONSE" | jq -r '.imported')
    echo -e "${GREEN}✅ Successfully restored $IMPORTED embeddings${NC}"
  else
    echo -e "${RED}❌ Failed to restore embeddings${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
  fi
fi

# Get stats
echo -e "\n${GREEN}📊 Final Statistics:${NC}"
STATS=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"get_stats"}')

echo "$STATS" | jq '{
  players: {
    total: .players.totalPlayers,
    active: .players.activeCount,
    injured: .players.injuredCount
  },
  embeddings: {
    total: .embeddings.totalEmbedded,
    avgLength: .embeddings.averageContentLength
  }
}'

echo -e "\n${GREEN}✨ Restore complete!${NC}"
