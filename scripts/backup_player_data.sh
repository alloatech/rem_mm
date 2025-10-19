#!/bin/bash

# Backup script for player data
# Exports players_raw and player_embeddings_selective to JSON files

set -e

BACKUP_DIR="./backups"
SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}💾 rem_mm Player Data Backup${NC}"
echo "================================"

# Create backup directory
mkdir -p "$BACKUP_DIR/players"
mkdir -p "$BACKUP_DIR/embeddings"

# Check if JWT token is provided
if [ -z "$JWT_TOKEN" ]; then
  echo -e "${YELLOW}⚠️  JWT_TOKEN not set. Getting fresh token...${NC}"
  JWT_TOKEN=$(curl -s -X POST 'http://127.0.0.1:54321/auth/v1/token?grant_type=password' \
    -H 'apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' \
    -H 'Content-Type: application/json' \
    -d '{"email":"jc@alloatech.com","password":"monkey"}' | jq -r '.access_token')
  
  if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" == "null" ]; then
    echo -e "${RED}❌ Failed to get JWT token. Check credentials.${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ Got JWT token${NC}"
fi

# Export players
echo -e "\n${GREEN}📤 Exporting players...${NC}"
PLAYERS_FILE="$BACKUP_DIR/players/players_$TIMESTAMP.json"
curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"export_players"}' > "$PLAYERS_FILE"

if [ $? -eq 0 ] && [ -f "$PLAYERS_FILE" ]; then
  PLAYER_COUNT=$(cat "$PLAYERS_FILE" | jq -r '.count')
  FILE_SIZE=$(du -h "$PLAYERS_FILE" | cut -f1)
  echo -e "${GREEN}✅ Exported $PLAYER_COUNT players ($FILE_SIZE)${NC}"
  
  # Create "latest" symlink
  ln -sf "players/players_$TIMESTAMP.json" "$BACKUP_DIR/players_latest.json"
else
  echo -e "${RED}❌ Failed to export players${NC}"
  exit 1
fi

# Export embeddings
echo -e "\n${GREEN}📤 Exporting embeddings...${NC}"
EMBEDDINGS_FILE="$BACKUP_DIR/embeddings/embeddings_$TIMESTAMP.json"
curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"export_embeddings"}' > "$EMBEDDINGS_FILE"

if [ $? -eq 0 ] && [ -f "$EMBEDDINGS_FILE" ]; then
  EMBEDDING_COUNT=$(cat "$EMBEDDINGS_FILE" | jq -r '.count')
  FILE_SIZE=$(du -h "$EMBEDDINGS_FILE" | cut -f1)
  echo -e "${GREEN}✅ Exported $EMBEDDING_COUNT embeddings ($FILE_SIZE)${NC}"
  
  # Create "latest" symlink
  ln -sf "embeddings/embeddings_$TIMESTAMP.json" "$BACKUP_DIR/embeddings_latest.json"
else
  echo -e "${RED}❌ Failed to export embeddings${NC}"
  exit 1
fi

# Get stats
echo -e "\n${GREEN}📊 Backup Statistics:${NC}"
echo "   Players:    $PLAYER_COUNT ($FILE_SIZE)"
echo "   Embeddings: $EMBEDDING_COUNT"
echo "   Timestamp:  $TIMESTAMP"
echo "   Location:   $BACKUP_DIR/"

# Cleanup old backups (keep last 7 days)
echo -e "\n${GREEN}🧹 Cleaning up old backups...${NC}"
find "$BACKUP_DIR/players" -name "players_*.json" -mtime +7 -delete
find "$BACKUP_DIR/embeddings" -name "embeddings_*.json" -mtime +7 -delete

echo -e "\n${GREEN}✨ Backup complete!${NC}"
echo "   To restore: ./scripts/restore_player_data.sh"
