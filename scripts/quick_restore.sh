#!/bin/bash

# Quick Restore from Storage Backup
# Use this after a db reset to restore embeddings without paying for re-generation

set -e

# Load environment
if [ -f .env ]; then
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
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}💾 rem_mm Quick Restore${NC}"
echo "============================"
echo ""

# Authenticate
echo -e "${GREEN}🔐 Authenticating...${NC}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"

AUTH_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")

JWT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token')

if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" == "null" ]; then
  echo -e "${RED}❌ Failed to authenticate${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Authenticated${NC}"

# List available backups
echo -e "\n${GREEN}📦 Checking available backups...${NC}"
BACKUPS_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"list_backups","data":{"data_type":"embeddings"}}')

BACKUP_COUNT=$(echo "$BACKUPS_RESPONSE" | jq '.backups | length')

if [ "$BACKUP_COUNT" -eq 0 ]; then
  echo -e "${RED}❌ No backups found${NC}"
  echo "Run ./scripts/complete_bootstrap.sh first to create embeddings"
  exit 1
fi

echo -e "${GREEN}✅ Found $BACKUP_COUNT backup(s)${NC}\n"
echo "$BACKUPS_RESPONSE" | jq -r '.backups[] | "  • \(.filename) - \(.size_mb)MB - \(.record_count) records - \(.created_at)"'

# Get latest backup
LATEST_BACKUP=$(echo "$BACKUPS_RESPONSE" | jq -r '.backups[0].filename')
BACKUP_RECORDS=$(echo "$BACKUPS_RESPONSE" | jq -r '.backups[0].record_count')

echo -e "\n${CYAN}Will restore: ${BLUE}$LATEST_BACKUP${NC}"
echo -e "${CYAN}Records: ${BLUE}$BACKUP_RECORDS${NC}"

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted"
  exit 0
fi

# Restore
echo -e "\n${GREEN}⏳ Restoring embeddings from backup...${NC}"
RESTORE_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"restore_from_storage\",\"data\":{\"filename\":\"$LATEST_BACKUP\"}}")

RESTORE_SUCCESS=$(echo "$RESTORE_RESPONSE" | jq -r '.success // false')

if [ "$RESTORE_SUCCESS" == "true" ]; then
  RESTORED_COUNT=$(echo "$RESTORE_RESPONSE" | jq -r '.records_restored')
  echo -e "${GREEN}✅ Restored $RESTORED_COUNT embeddings${NC}"
  
  # Show stats
  echo -e "\n${GREEN}📊 Verification:${NC}"
  EMBED_COUNT=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM player_embeddings_selective;" 2>/dev/null | xargs)
  COST_SAVED=$(echo "scale=4; $EMBED_COUNT * 0.0001" | bc)
  
  echo -e "  Embeddings in DB: ${BLUE}$EMBED_COUNT${NC}"
  echo -e "  Cost saved:       ${GREEN}\$$COST_SAVED${NC} (didn't re-generate!)"
  echo -e "  Time saved:       ${GREEN}3-5 minutes${NC}"
  
  echo -e "\n${GREEN}✨ Restore complete!${NC}"
  echo -e "${CYAN}Note: You may want to re-sync leagues/rosters (FREE):${NC}"
  echo -e "  curl -X POST '$SUPABASE_URL/functions/v1/user-sync' \\"
  echo -e "    -H 'Authorization: Bearer \$JWT_TOKEN' \\"
  echo -e "    -d '{\"action\":\"sync_rosters\",\"sleeper_user_id\":\"872612101674491904\"}'"
else
  echo -e "${RED}❌ Restore failed${NC}"
  ERROR=$(echo "$RESTORE_RESPONSE" | jq -r '.error // "Unknown error"')
  echo -e "Error: $ERROR"
  exit 1
fi
