#!/bin/bash

# Refresh, Bootstrap, Test - The Standard Workflow
# Complete clean slate → full setup → verify

set -e

echo "🔄 REFRESH → BOOTSTRAP → TEST"
echo "================================"
echo ""

# STEP 1: REFRESH (Clean Slate)
echo "📍 Step 1/3: REFRESH - Clean database slate"
echo "   Running: supabase db reset"
supabase db reset
echo "✅ Database refreshed"
echo ""

# STEP 2: BOOTSTRAP (Full Setup)
echo "📍 Step 2/3: BOOTSTRAP - Complete setup"
echo "   Running: complete_bootstrap.sh"
echo "y" | bash scripts/complete_bootstrap.sh
echo "✅ Bootstrap complete"
echo ""

# STEP 3: TEST (Verify)
echo "📍 Step 3/3: TEST - Verify setup"
echo ""

# Test 1: Check user exists
echo "🧪 Test 1: User exists"
USER_COUNT=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM app_users WHERE sleeper_user_id = '872612101674491904';")
echo "   Found $USER_COUNT user(s)"
if [ "$USER_COUNT" -eq 1 ]; then
  echo "   ✅ PASS"
else
  echo "   ❌ FAIL: Expected 1 user"
  exit 1
fi
echo ""

# Test 2: Check league exists
echo "🧪 Test 2: League synced"
LEAGUE_COUNT=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM leagues;")
echo "   Found $LEAGUE_COUNT league(s)"
if [ "$LEAGUE_COUNT" -ge 1 ]; then
  echo "   ✅ PASS"
else
  echo "   ❌ FAIL: Expected at least 1 league"
  exit 1
fi
echo ""

# Test 3: Check league_memberships exists
echo "🧪 Test 3: League memberships created"
MEMBERSHIP_COUNT=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM league_memberships WHERE app_user_id = (SELECT id FROM app_users WHERE sleeper_user_id = '872612101674491904');")
echo "   Found $MEMBERSHIP_COUNT membership(s)"
if [ "$MEMBERSHIP_COUNT" -ge 1 ]; then
  echo "   ✅ PASS"
else
  echo "   ❌ FAIL: Expected at least 1 membership"
  exit 1
fi
echo ""

# Test 4: Check rosters synced
echo "🧪 Test 4: Rosters synced"
ROSTER_COUNT=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM user_rosters;")
echo "   Found $ROSTER_COUNT roster(s)"
if [ "$ROSTER_COUNT" -ge 1 ]; then
  echo "   ✅ PASS"
else
  echo "   ❌ FAIL: Expected at least 1 roster"
  exit 1
fi
echo ""

# Test 5: Check th0rjc's roster is linked
echo "🧪 Test 5: User's roster linked (app_user_id set)"
LINKED_ROSTER=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT app_user_id FROM user_rosters WHERE sleeper_owner_id = '872612101674491904';")
echo "   app_user_id: $LINKED_ROSTER"
if [ -n "$LINKED_ROSTER" ] && [ "$LINKED_ROSTER" != " " ]; then
  echo "   ✅ PASS"
else
  echo "   ❌ FAIL: app_user_id is NULL - roster not linked!"
  echo ""
  echo "🔍 Debugging info:"
  psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "SELECT sleeper_owner_id, owner_display_name, app_user_id FROM user_rosters WHERE sleeper_owner_id = '872612101674491904';"
  exit 1
fi
echo ""

# Test 6: Check get_user_leagues works
echo "🧪 Test 6: get_user_leagues() returns data"
APP_USER_ID=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT id FROM app_users WHERE sleeper_user_id = '872612101674491904';" | tr -d ' ')
LEAGUE_DATA=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT COUNT(*) FROM get_user_leagues('$APP_USER_ID'::uuid);")
echo "   Found $LEAGUE_DATA league(s) via function"
if [ "$LEAGUE_DATA" -ge 1 ]; then
  echo "   ✅ PASS"
else
  echo "   ❌ FAIL: get_user_leagues returned no data"
  exit 1
fi
echo ""

# Test 7: Check league has new fields
echo "🧪 Test 7: League has status/settings/metadata"
LEAGUE_STATUS=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "SELECT status FROM leagues LIMIT 1;")
echo "   League status: $LEAGUE_STATUS"
if [ -n "$LEAGUE_STATUS" ] && [ "$LEAGUE_STATUS" != " " ]; then
  echo "   ✅ PASS"
else
  echo "   ⚠️  WARNING: League status is NULL"
fi
echo ""

# Test 8: Check RLS permissions (simulates Flutter app)
echo "🧪 Test 8: RLS - Function works as authenticated user"
SUPABASE_USER_ID="00000000-0000-0000-0000-000000000001"
RLS_LEAGUE_COUNT=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -t -c "
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '$SUPABASE_USER_ID';
SELECT COUNT(*) FROM get_user_leagues('$APP_USER_ID'::uuid);
")
echo "   Found $RLS_LEAGUE_COUNT league(s) with RLS enabled"
if [ "$RLS_LEAGUE_COUNT" -ge 1 ]; then
  echo "   ✅ PASS - RLS working!"
else
  echo "   ❌ FAIL: Function blocked by RLS"
  exit 1
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ALL TESTS PASSED!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 Ready to test in Flutter app"
echo "   Run: flutter run (then hot restart)"
