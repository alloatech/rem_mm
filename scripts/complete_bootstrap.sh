#!/bin/bash

# Complete Bootstrap - Includes league sync and targeted embedding
# This is the recommended workflow for initial system setup

set -e

# Load environment variables from .env if it exists
if [ -f .env ]; then
  echo "📄 Loading environment from .env file..."
  export $(grep -v '^#' .env | xargs)
fi

SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
ADMIN_EMAIL="${ADMIN_EMAIL:-jc@alloatech.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-monkey}"
ADMIN_SLEEPER_ID="${ADMIN_SLEEPER_ID:-872612101674491904}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}🚀 rem_mm Complete Bootstrap${NC}"
echo -e "${CYAN}   (with league sync + targeted embedding)${NC}"
echo "============================================"
echo ""

# Get JWT token
echo -e "${GREEN}🔐 Step 1/6: Authenticating...${NC}"
if [ -z "$JWT_TOKEN" ]; then
  SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
  
  AUTH_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")
  
  JWT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token')
  
  if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" == "null" ]; then
    echo -e "${RED}❌ Failed to authenticate${NC}"
    echo "Response: $AUTH_RESPONSE"
    exit 1
  fi
fi
echo -e "${GREEN}✅ Authenticated as $ADMIN_EMAIL${NC}"

# Step 2: Fetch all players (raw data)
echo -e "\n${GREEN}📥 Step 2/6: Fetching player data from Sleeper...${NC}"

# Check if players already exist
EXISTING_PLAYERS=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM players_raw;" 2>/dev/null | xargs)

if [ "$EXISTING_PLAYERS" -gt 0 ]; then
  echo -e "${CYAN}   Already have $EXISTING_PLAYERS players in database${NC}"
  echo -e "${CYAN}   Checking if update needed...${NC}"
fi

RAW_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/simple-ingestion" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"test_mode":false}')

# Poll for status (just wait a bit for completion)
sleep 3

STATUS_RESPONSE=$(curl -s "$SUPABASE_URL/functions/v1/simple-ingestion/status")
PLAYERS_SYNCED=$(echo "$STATUS_RESPONSE" | jq -r '.status.progress // 0')

# Get final count from database (more reliable than progress)
FINAL_PLAYER_COUNT=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM players_raw;" 2>/dev/null | xargs)

if [ "$EXISTING_PLAYERS" -gt 0 ] && [ "$EXISTING_PLAYERS" -eq "$FINAL_PLAYER_COUNT" ]; then
  echo -e "${GREEN}✅ Player data current ($FINAL_PLAYER_COUNT players, no changes needed)${NC}"
else
  echo -e "${GREEN}✅ Synced $FINAL_PLAYER_COUNT players to database${NC}"
fi

# Use final count for summary
PLAYERS_SYNCED=$FINAL_PLAYER_COUNT

# Step 3: Sync leagues
echo -e "\n${GREEN}🏈 Step 3/6: Syncing admin leagues...${NC}"
echo -e "${CYAN}   (Auto-detecting your active leagues from Sleeper)${NC}"
LEAGUES_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"sync_leagues\",\"sleeper_user_id\":\"$ADMIN_SLEEPER_ID\"}")

LEAGUES_SYNCED=$(echo "$LEAGUES_RESPONSE" | jq -r '.leagues_synced // 0')

# Show league names (use -A to avoid xargs quote issues)
LEAGUE_NAMES=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -A -t -c "
  SELECT l.league_name 
  FROM leagues l
  INNER JOIN league_memberships lm ON l.id = lm.league_id
  WHERE lm.app_user_id = (SELECT id FROM app_users WHERE sleeper_user_id = '$ADMIN_SLEEPER_ID')
  ORDER BY l.league_name;
" 2>/dev/null)

echo -e "${GREEN}✅ Synced $LEAGUES_SYNCED league(s)${NC}"
if [ -n "$LEAGUE_NAMES" ]; then
  echo "$LEAGUE_NAMES" | while IFS= read -r league_name; do
    if [ -n "$league_name" ]; then
      echo -e "${CYAN}   • $league_name${NC}"
    fi
  done
fi
echo -e "${CYAN}   Note: This varies year-to-year based on your participation${NC}"

# Step 4: Sync ALL rosters (multi-user)
echo -e "\n${GREEN}🏆 Step 4/6: Syncing ALL rosters in leagues...${NC}"
echo -e "${CYAN}   (This includes all teams, not just admin)${NC}"
ROSTERS_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"action\":\"sync_rosters\",\"sleeper_user_id\":\"$ADMIN_SLEEPER_ID\"}")

ROSTERS_SYNCED=$(echo "$ROSTERS_RESPONSE" | jq -r '.rosters_synced // 0')

# Show team names with owner names in format: <Team Name> [owner]
TEAM_INFO=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "
  SELECT 
    CASE 
      WHEN ur.team_name IS NOT NULL AND ur.team_name != '' 
      THEN ur.team_name || ' [' || COALESCE(ur.owner_display_name, 'Unknown') || ']'
      ELSE COALESCE(ur.owner_display_name, 'Team ' || ur.sleeper_roster_id)
    END as display,
    CASE 
      WHEN ur.app_user_id = (SELECT id FROM app_users WHERE sleeper_user_id = '$ADMIN_SLEEPER_ID') 
      THEN '(YOU)' 
      ELSE '' 
    END as indicator
  FROM user_rosters ur
  JOIN leagues l ON ur.league_id = l.id
  JOIN league_memberships lm ON l.id = lm.league_id
  WHERE lm.app_user_id = (SELECT id FROM app_users WHERE sleeper_user_id = '$ADMIN_SLEEPER_ID')
  ORDER BY ur.sleeper_roster_id;
" 2>/dev/null)

echo -e "${GREEN}✅ Synced $ROSTERS_SYNCED roster(s)${NC}"
if [ -n "$TEAM_INFO" ]; then
  echo -e "${CYAN}   Teams sync'd:${NC}"
  echo "$TEAM_INFO" | while IFS='|' read -r display indicator; do
    display=$(echo "$display" | xargs)
    indicator=$(echo "$indicator" | xargs)
    if [ -n "$display" ]; then
      if [ "$indicator" == "(YOU)" ]; then
        echo -e "${GREEN}   • $display ${BOLD}$indicator${NC}"
      else
        echo -e "${CYAN}   • $display${NC}"
      fi
    fi
  done
fi
echo -e "${CYAN}   💡 TODO: Add explicit 'my team' selection UI (see docs/TODO_MY_TEAM_FEATURE.md)${NC}"

ROSTERS_SYNCED=$(echo "$ROSTERS_RESPONSE" | jq -r '.rosters_synced // 0')
echo -e "${GREEN}✅ Synced $ROSTERS_SYNCED roster(s) across all teams${NC}"


# Step 5: Load historical weekly roster player points
# Get all league IDs
LEAGUE_IDS=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -A -t -c "SELECT sleeper_league_id FROM leagues;" 2>/dev/null)

ERROR_COUNT=0
ERROR_LOG="/tmp/bootstrap_errors.log"
echo "" > "$ERROR_LOG"
for LEAGUE_ID in $LEAGUE_IDS; do
  echo -e "${CYAN}   Processing league: $LEAGUE_ID${NC}"
  for WEEK in $(seq 1 18); do
    MATCHUPS_JSON=$(curl -s "https://api.sleeper.app/v1/league/$LEAGUE_ID/matchups/$WEEK")
    CURL_EXIT=$?
    if [ $CURL_EXIT -ne 0 ] || [ -z "$MATCHUPS_JSON" ] || [ "$MATCHUPS_JSON" = "null" ]; then
      echo -e "${RED}   Week $WEEK: Failed to fetch matchup data (curl exit $CURL_EXIT). Stopping.${NC}"
      echo "LEAGUE $LEAGUE_ID WEEK $WEEK: curl error $CURL_EXIT" >> "$ERROR_LOG"
      ERROR_COUNT=$((ERROR_COUNT+1))
      break
    fi
    NONZERO=$(echo "$MATCHUPS_JSON" | jq '[.[].starters_points[]?] | map(select(. != 0)) | length')
    JQ_EXIT=$?
    if [ $JQ_EXIT -ne 0 ]; then
      echo -e "${RED}   Week $WEEK: jq error parsing points.${NC}"
      echo "LEAGUE $LEAGUE_ID WEEK $WEEK: jq error $JQ_EXIT" >> "$ERROR_LOG"
      ERROR_COUNT=$((ERROR_COUNT+1))
      break
    fi
    if [ "$NONZERO" -eq 0 ]; then
      echo -e "${YELLOW}   Week $WEEK: All points zero, assuming future week. Stopping.${NC}"
      break
    fi
    echo -e "${CYAN}   Week $WEEK: Loading points...${NC}"
    MATCHUP_COUNT=$(echo "$MATCHUPS_JSON" | jq 'length')
    echo -e "${CYAN}      Found $MATCHUP_COUNT matchups for week $WEEK${NC}"
    echo "$MATCHUPS_JSON" | jq -c '.[]' | while read -r matchup; do
      ROSTER_ID=$(echo "$matchup" | jq -r '.roster_id')
      if [ -z "$ROSTER_ID" ]; then
        echo -e "${RED}      Missing roster_id in matchup. Skipping.${NC}"
        echo "LEAGUE $LEAGUE_ID WEEK $WEEK: missing roster_id" >> "$ERROR_LOG"
        ERROR_COUNT=$((ERROR_COUNT+1))
        continue
      fi
      echo -e "${CYAN}      Processing roster $ROSTER_ID${NC}"
            # Convert starters and players to arrays (POSIX compatible)
      STARTERS_ARR=()
      if echo "$matchup" | jq -r '.starters[]?' > /tmp/starters.$$ 2>/dev/null; then
        while IFS= read -r line; do
          STARTERS_ARR+=("$line")
        done < /tmp/starters.$$
        rm /tmp/starters.$$
        echo -e "${CYAN}      STARTERS_ARR has ${#STARTERS_ARR[@]} players${NC}"
      else
        echo -e "${RED}      Error parsing starters for roster $ROSTER_ID. Skipping.${NC}"
        echo "LEAGUE $LEAGUE_ID WEEK $WEEK ROSTER $ROSTER_ID: starters jq error" >> "$ERROR_LOG"
        ERROR_COUNT=$((ERROR_COUNT+1))
        continue
      fi

      # Convert reserve (injured reserve) to array
      RESERVE_ARR=()
      if echo "$matchup" | jq -r '.reserve[]?' > /tmp/reserve.$$ 2>/dev/null; then
        while IFS= read -r line; do
          RESERVE_ARR+=("$line")
        done < /tmp/reserve.$$
        rm /tmp/reserve.$$
        echo -e "${CYAN}      RESERVE_ARR has ${#RESERVE_ARR[@]} players${NC}"
      else
        echo -e "${CYAN}      No injured reserve players found${NC}"
      fi

      PLAYERS_ARR=()
      if echo "$matchup" | jq -r '.players_points | keys[]' > /tmp/players.$$ 2>/dev/null; then
        while IFS= read -r line; do
          PLAYERS_ARR+=("$line")
        done < /tmp/players.$$
        rm /tmp/players.$$
        echo -e "${CYAN}      PLAYERS_ARR has ${#PLAYERS_ARR[@]} players${NC}"
      else
        echo -e "${RED}      Error parsing players_points for roster $ROSTER_ID. Skipping.${NC}"
        echo "LEAGUE $LEAGUE_ID WEEK $WEEK ROSTER $ROSTER_ID: players_points jq error" >> "$ERROR_LOG"
        ERROR_COUNT=$((ERROR_COUNT+1))
        continue
      fi

            # starters
      for PLAYER_ID in "${STARTERS_ARR[@]}"; do
        POINTS=$(echo "$matchup" | jq -r ".players_points[\"$PLAYER_ID\"] // 0")
        PLAYER_NAME=$(psql -q postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COALESCE(full_name, '$PLAYER_ID') FROM players_raw WHERE player_id = '$PLAYER_ID' LIMIT 1;" 2>/dev/null)
        echo -ne "\rProcessing Week $WEEK | Roster $ROSTER_ID | $PLAYER_NAME ($POINTS pts)"
        PSQL_CMD="INSERT INTO live_roster_player_points (league_id, roster_id, week, player_id, points, section) VALUES ('$LEAGUE_ID', '$ROSTER_ID', '$WEEK', '$PLAYER_ID', '$POINTS', 'starters') ON CONFLICT (league_id, roster_id, week, player_id) DO UPDATE SET points = EXCLUDED.points, section = 'starters', last_updated = now();"
        psql -q postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "$PSQL_CMD"
        PSQL_EXIT=$?
        if [ -n "$PSQL_EXIT" ] && [ "$PSQL_EXIT" -ne 0 ]; then
          echo -e "${RED}        Error inserting starter $PLAYER_ID for roster $ROSTER_ID week $WEEK${NC}"
          echo "LEAGUE $LEAGUE_ID WEEK $WEEK ROSTER $ROSTER_ID PLAYER $PLAYER_ID: starter insert error $PSQL_EXIT" >> "$ERROR_LOG"
          ERROR_COUNT=$((ERROR_COUNT+1))
        fi
      done

      # injured reserve: players from reserve array (0 points)
      for PLAYER_ID in "${RESERVE_ARR[@]}"; do
        POINTS=0
        PLAYER_NAME=$(psql -q postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COALESCE(full_name, '$PLAYER_ID') FROM players_raw WHERE player_id = '$PLAYER_ID' LIMIT 1;" 2>/dev/null)
        echo -ne "\rProcessing Week $WEEK | Roster $ROSTER_ID | $PLAYER_NAME ($POINTS pts)"
        PSQL_CMD="INSERT INTO live_roster_player_points (league_id, roster_id, week, player_id, points, section) VALUES ('$LEAGUE_ID', '$ROSTER_ID', '$WEEK', '$PLAYER_ID', '$POINTS', 'injured reserve') ON CONFLICT (league_id, roster_id, week, player_id) DO UPDATE SET points = EXCLUDED.points, section = 'injured reserve', last_updated = now();"
        psql -q postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "$PSQL_CMD"
        PSQL_EXIT=$?
        if [ -n "$PSQL_EXIT" ] && [ "$PSQL_EXIT" -ne 0 ]; then
          echo -e "${RED}        Error inserting injured reserve $PLAYER_ID for roster $ROSTER_ID week $WEEK${NC}"
          echo "LEAGUE $LEAGUE_ID WEEK $WEEK ROSTER $ROSTER_ID PLAYER $PLAYER_ID: injured reserve insert error $PSQL_EXIT" >> "$ERROR_LOG"
          ERROR_COUNT=$((ERROR_COUNT+1))
        fi
      done

      # bench: players minus starters minus injured reserve
      for PLAYER_ID in "${PLAYERS_ARR[@]}"; do
        IS_STARTER=false
        for S_ID in "${STARTERS_ARR[@]}"; do
          if [ "$PLAYER_ID" = "$S_ID" ]; then
            IS_STARTER=true
            break
          fi
        done
        IS_RESERVE=false
        for R_ID in "${RESERVE_ARR[@]}"; do
          if [ "$PLAYER_ID" = "$R_ID" ]; then
            IS_RESERVE=true
            break
          fi
        done
        if [ "$IS_STARTER" = false ] && [ "$IS_RESERVE" = false ]; then
          POINTS=$(echo "$matchup" | jq -r ".players_points[\"$PLAYER_ID\"] // 0")
          PLAYER_NAME=$(psql -q postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COALESCE(full_name, '$PLAYER_ID') FROM players_raw WHERE player_id = '$PLAYER_ID' LIMIT 1;" 2>/dev/null)
          echo -ne "\rProcessing Week $WEEK | Roster $ROSTER_ID | $PLAYER_NAME ($POINTS pts)"
          PSQL_CMD="INSERT INTO live_roster_player_points (league_id, roster_id, week, player_id, points, section) VALUES ('$LEAGUE_ID', '$ROSTER_ID', '$WEEK', '$PLAYER_ID', '$POINTS', 'bench') ON CONFLICT (league_id, roster_id, week, player_id) DO UPDATE SET points = EXCLUDED.points, section = 'bench', last_updated = now();"
          psql -q postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "$PSQL_CMD"
          PSQL_EXIT=$?
          if [ -n "$PSQL_EXIT" ] && [ "$PSQL_EXIT" -ne 0 ]; then
            echo -e "${RED}        Error inserting bench $PLAYER_ID for roster $ROSTER_ID week $WEEK${NC}"
            echo "LEAGUE $LEAGUE_ID WEEK $WEEK ROSTER $ROSTER_ID PLAYER $PLAYER_ID: bench insert error $PSQL_EXIT" >> "$ERROR_LOG"
            ERROR_COUNT=$((ERROR_COUNT+1))
          fi
        fi
      done
      echo ""  # New line after roster processing
    done
    done
  done
if [ $ERROR_COUNT -gt 0 ]; then
  echo -e "${RED}❌ $ERROR_COUNT errors occurred during roster player points loading. See $ERROR_LOG for details.${NC}"
else
  echo -e "${GREEN}✅ Roster player points loaded with no errors.${NC}"
fi

# Continue with embedding and summary steps

# Step 6: Create embeddings (targeted)
if [ -z "$GEMINI_API_KEY" ]; then
  echo -e "\n${YELLOW}⚠️  GEMINI_API_KEY not set. Skipping embeddings.${NC}"
  echo "   Add to .env file and re-run to create embeddings."
else
  echo -e "\n${GREEN}🧠 Step 6/6: Creating embeddings (targeted - skill positions only)...${NC}"
  
  read -p "Create embeddings for $SKILL_PLAYER_COUNT skill position players? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🧠 Creating embeddings for $SKILL_PLAYER_COUNT skill position players (out of $PLAYER_COUNT total rostered)...${NC}"
    
    # Start embedding process
    EMBED_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/simple-ingestion" \
      -H "Authorization: Bearer $JWT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"test_mode\":false,\"gemini_api_key\":\"$GEMINI_API_KEY\",\"player_ids\":$PLAYER_IDS}")
    
    # Poll for status with real-time progress (overwrites same line)
    echo -e "${CYAN}⏳ Embedding in progress (this may take 2-3 minutes)...${NC}"
    echo -e "${CYAN}   Checking Docker logs for real-time status...${NC}"
    
    LAST_PROGRESS=0
    START_TIME=$(date +%s)
    
    # Poll Edge Function logs for real-time status
    for i in {1..180}; do
      sleep 1
      
      # Get latest embedding status from Docker logs
      LATEST_LOG=$(docker logs --since 3s supabase_edge_runtime_rem_mm 2>&1 | grep "📊 Status:" | tail -1)
      
      if [ -n "$LATEST_LOG" ]; then
        # Extract the message after "Status: "
        STATUS_MSG=$(echo "$LATEST_LOG" | sed -n 's/.*📊 Status: \(.*\)/\1/p')
        
        # Extract progress numbers if present (e.g., "(162/192)")
        if [[ "$STATUS_MSG" =~ \(([0-9]+)/([0-9]+)\) ]]; then
          CURRENT_PROGRESS="${BASH_REMATCH[1]}"
          TOTAL="${BASH_REMATCH[2]}"
          
          # Only update if progress changed
          if [ "$CURRENT_PROGRESS" != "$LAST_PROGRESS" ]; then
            PERCENT=$((CURRENT_PROGRESS * 100 / TOTAL))
            # Use \r to overwrite the same line
            printf "\r${CYAN}   [%3d%%] %s${NC}" "$PERCENT" "$STATUS_MSG"
            LAST_PROGRESS=$CURRENT_PROGRESS
          fi
        fi
      fi
      
      # Check if complete (look for completion message in logs)
      COMPLETE_LOG=$(docker logs --since 3s supabase_edge_runtime_rem_mm 2>&1 | grep -E "Complete!|complete_with_errors" | tail -1)
      if [ -n "$COMPLETE_LOG" ]; then
        printf "\n"  # New line after progress bar
        break
      fi
      
      # Timeout after 3 minutes
      ELAPSED=$(($(date +%s) - START_TIME))
      if [ $ELAPSED -gt 180 ]; then
        printf "\n"
        echo -e "${YELLOW}⚠️  Timeout after 3 minutes. Check logs for status.${NC}"
        break
      fi
    done
    
    printf "\n"  # Ensure clean line after progress
    echo -e "${GREEN}✅ Embedding complete!${NC}"
    
    # Show embedding snapshot
    echo -e "\n${BLUE}📸 Embedding Snapshot:${NC}"
    EMBED_SAMPLE=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "
      SELECT 
        pr.full_name,
        pr.position,
        pr.team,
        'embedded' as status
      FROM player_embeddings_selective pes
      JOIN players_raw pr ON pes.player_id = pr.player_id
      ORDER BY pr.position, pr.full_name
      LIMIT 5;
    " 2>/dev/null)
    
    if [ -n "$EMBED_SAMPLE" ]; then
      echo "$EMBED_SAMPLE" | while IFS='|' read -r name pos team status; do
        name=$(echo "$name" | xargs)
        pos=$(echo "$pos" | xargs)
        team=$(echo "$team" | xargs)
        echo -e "   ✓ ${GREEN}$name${NC} ($pos, $team)"
      done
      echo -e "${CYAN}   ... and $((PLAYER_COUNT - 5)) more players${NC}"
    fi
    
    echo -e "${GREEN}✅ Embeddings created for $PLAYER_COUNT players${NC}"
    
    # Verify Storage bucket exists before backing up
    echo -e "\n${GREEN}💾 Step 6b: Backing up embeddings to Supabase Storage...${NC}"
    BUCKET_CHECK=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT name FROM storage.buckets WHERE name = 'player-data-backups';" 2>/dev/null | xargs)
    
    if [ -z "$BUCKET_CHECK" ]; then
      echo -e "${RED}❌ Storage bucket 'player-data-backups' not found${NC}"
      echo -e "${YELLOW}   This bucket should have been created by migration 20251019083000_create_backup_system.sql${NC}"
      echo -e "${YELLOW}   Embeddings are safe in database, but not backed up to Storage${NC}"
    else
      echo -e "${GREEN}✅ Storage bucket 'player-data-backups' verified${NC}"
      echo -e "${CYAN}   (Protects your \$$ACTUAL_COST investment)${NC}"
      
      BACKUP_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin-v2" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"action":"backup_to_storage","data":{"data_type":"embeddings"}}')
      
      BACKUP_SUCCESS=$(echo "$BACKUP_RESPONSE" | jq -r '.success // false')
      if [ "$BACKUP_SUCCESS" == "true" ]; then
        BACKUP_FILE=$(echo "$BACKUP_RESPONSE" | jq -r '.filename // "unknown"')
        BACKUP_SIZE=$(echo "$BACKUP_RESPONSE" | jq -r '.size_mb // "unknown"')
        
        # Get actual file size from Storage if size_mb not in response
        if [ "$BACKUP_SIZE" == "null" ] || [ "$BACKUP_SIZE" == "unknown" ]; then
          BACKUP_SIZE=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "
            SELECT ROUND((metadata->>'size')::numeric / 1048576.0, 2) as size_mb
            FROM storage.objects 
            WHERE bucket_id = 'player-data-backups' AND name = '$BACKUP_FILE';
          " 2>/dev/null | xargs)
          if [ -z "$BACKUP_SIZE" ]; then
            BACKUP_SIZE="unknown"
          fi
        fi
        
        echo -e "${GREEN}✅ Embeddings backed up: $BACKUP_FILE (${BACKUP_SIZE}MB)${NC}"
        
        # Verify backup in Storage
        STORAGE_CHECK=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM storage.objects WHERE bucket_id = 'player-data-backups' AND name = '$BACKUP_FILE';" 2>/dev/null | xargs)
        if [ "$STORAGE_CHECK" == "1" ]; then
          echo -e "${GREEN}✅ Backup verified in Storage${NC}"
        else
          echo -e "${YELLOW}⚠️  Backup metadata exists but file not found in Storage${NC}"
        fi
      else
        echo -e "${YELLOW}⚠️  Backup failed (embeddings still in database)${NC}"
        BACKUP_ERROR=$(echo "$BACKUP_RESPONSE" | jq -r '.error // "Unknown error"')
        echo -e "${YELLOW}   Error: $BACKUP_ERROR${NC}"
      fi
    fi
  else
    echo "Skipped embeddings. Run ./scripts/smart_bootstrap.sh to create them later."
  fi
fi

echo -e "\n${GREEN}📊 Bootstrap Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  📥 Players synced:    ${BLUE}$PLAYERS_SYNCED${NC}"
echo -e "  🏈 Leagues synced:    ${BLUE}$LEAGUES_SYNCED${NC} (varies by season)"
echo -e "  🏆 Rosters synced:    ${BLUE}$ROSTERS_SYNCED${NC} (all teams)"
echo -e "  👥 Unique players:    ${BLUE}$PLAYER_COUNT${NC} (rostered)"
if [ -n "$GEMINI_API_KEY" ] && [[ $REPLY =~ ^[Yy]$ ]]; then
  ACTUAL_EMBED_COUNT=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM player_embeddings_selective;" 2>/dev/null | xargs)
  ACTUAL_COST=$(echo "scale=4; $ACTUAL_EMBED_COUNT * 0.0001" | bc)
  SAVED=$(echo "scale=4; 0.2964 - $ACTUAL_COST" | bc)
  # Fix percentage calculation - bc needs proper scale handling
  SAVED_PERCENT=$(echo "scale=2; ($SAVED * 100) / 0.2964" | bc | cut -d'.' -f1)
  echo -e "  🧠 Embeddings:        ${BLUE}$ACTUAL_EMBED_COUNT${NC} (targeted)"
  echo -e "  💰 Actual cost:       ${BLUE}\$$ACTUAL_COST${NC}"
  echo -e "  💸 Amount saved:      ${GREEN}\$$SAVED${NC} (~${SAVED_PERCENT}% savings)"
  
  # Check if backup exists
  BACKUP_CHECK=$(curl -s -X POST "$SUPABASE_URL/functions/v1/player-data-admin-v2" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"action":"list_backups","data":{"data_type":"embeddings"}}')
  BACKUP_COUNT=$(echo "$BACKUP_CHECK" | jq '.backups | length')
  if [ "$BACKUP_COUNT" -gt 0 ]; then
    LATEST_BACKUP=$(echo "$BACKUP_CHECK" | jq -r '.backups[0].filename')
    echo -e "  💾 Backup:            ${GREEN}$LATEST_BACKUP${NC} ✓"
  else
    echo -e "  💾 Backup:            ${YELLOW}Not found${NC}"
  fi
else
  echo -e "  🧠 Embeddings:        ${YELLOW}Not created${NC}"
  echo -e "  💰 Estimated cost:    ${CYAN}\$$(echo "scale=4; $PLAYER_COUNT * 0.0001" | bc)${NC} (when created)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${GREEN}✨ Bootstrap complete!${NC}"
echo ""
echo -e "\n${CYAN}Next steps:${NC}"
echo "  1. ✅ Raw player data loaded (can re-sync anytime - FREE)"
echo "  2. ✅ Your leagues and rosters synced (can refresh anytime - FREE)"
if [ -n "$GEMINI_API_KEY" ] && [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "  3. ✅ Embeddings created (backed up to Storage)"
  echo "  4. 💡 On db reset: Embeddings restore in 2-3 seconds from backup"
  echo "  5. 🚀 Ready to use! Test with: ./scripts/test_rag.sh"
else
  echo "  3. ⏭️  Run ./scripts/smart_bootstrap.sh to create embeddings"
  echo "  4. 🚀 Then test with: ./scripts/test_rag.sh"
fi
echo ""
echo -e "${BLUE}📦 Storage Backup Info:${NC}"
echo "  • Embeddings backed up to: player-data-backups bucket"
echo "  • Survives db resets: YES"
echo "  • Restore time: 2-3 seconds"
echo "  • Re-sync leagues: FREE anytime"
echo ""
