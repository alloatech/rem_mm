// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// User Sync Edge Function
// Handles user registration, league discovery, and roster syncing
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { logSecurityEvent } from '../_shared/auth.ts'

declare const Deno: any

console.log("user-sync function loaded")

// Type definitions
interface SleeperUser {
  user_id: string
  username: string
  display_name: string
  avatar?: string
}

interface SleeperLeague {
  league_id: string
  name: string
  season: number
  sport: string
  settings: any
  scoring_settings?: any
  roster_positions: string[]
  total_rosters: number
  avatar?: string  // League avatar ID from Sleeper
  status?: string  // League status: pre_draft, drafting, in_season, complete
  metadata?: any   // Additional league metadata
}

interface SleeperRoster {
  roster_id: number
  owner_id: string
  players: string[]
  starters: string[]
  reserve?: string[]
  taxi?: string[]
  settings: any
  metadata?: {
    [key: string]: string
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400'
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { action, sleeper_user_id, sleeper_username } = await req.json()

    if (!sleeper_user_id) {
      return new Response(
        JSON.stringify({ error: 'sleeper_user_id is required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Initialize Supabase clients
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    // Get auth token from request
    const authHeader = req.headers.get('Authorization')
    const jwt = authHeader?.replace('Bearer ', '')
    console.log('🔐 Authorization header present:', !!authHeader)
    console.log('🔐 JWT token (first 50 chars):', jwt?.substring(0, 50))
    
    // Create client for auth (with user JWT) - Pass JWT directly to getUser()
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey)
    
    // Create service role client for database operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 🔐 AUDIT: Function entry
    await logSecurityEvent(
      supabase,
      'user_sync_enter',
      sleeper_user_id,
      { action, sleeper_username, function: 'user-sync' },
      req
    )

    let result
    switch (action) {
      case 'register_user':
        await logSecurityEvent(supabase, 'user_registration_start', sleeper_user_id, { action }, req)
        result = await registerUser(supabase, supabaseClient, jwt, sleeper_user_id, sleeper_username)
        await logSecurityEvent(supabase, 'user_registration_complete', sleeper_user_id, { action }, req)
        return result
      
      case 'sync_leagues':
        await logSecurityEvent(supabase, 'league_sync_start', sleeper_user_id, { action }, req)
        result = await syncUserLeagues(supabase, sleeper_user_id)
        await logSecurityEvent(supabase, 'league_sync_complete', sleeper_user_id, { action }, req)
        return result
      
      case 'sync_rosters':
        await logSecurityEvent(supabase, 'roster_sync_start', sleeper_user_id, { action }, req)
        result = await syncUserRosters(supabase, sleeper_user_id)
        await logSecurityEvent(supabase, 'roster_sync_complete', sleeper_user_id, { action }, req)
        return result
      
      case 'full_sync':
        await logSecurityEvent(supabase, 'full_sync_start', sleeper_user_id, { action, sleeper_username }, req)
        result = await fullUserSync(supabase, supabaseClient, jwt, sleeper_user_id, sleeper_username)
        await logSecurityEvent(supabase, 'full_sync_complete', sleeper_user_id, { action }, req)
        return result
      
      case 'get_rostered_players':
        await logSecurityEvent(supabase, 'get_rostered_players', sleeper_user_id, { action }, req)
        result = await getRosteredPlayers(supabase, sleeper_user_id)
        return result
      
      default:
        await logSecurityEvent(supabase, 'user_sync_invalid_action', sleeper_user_id, { action }, req)
        return new Response(
          JSON.stringify({ error: 'Invalid action. Use: register_user, sync_leagues, sync_rosters, full_sync, or get_rostered_players' }),
          { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
    }

  } catch (error) {
    console.error('Error in user-sync function:', error)
    
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
    
    // 🔐 AUDIT: Error occurred
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const supabase = createClient(supabaseUrl, supabaseKey)
      await logSecurityEvent(supabase, 'user_sync_error', null, { error: errorMessage }, req)
    } catch (auditError) {
      console.error('❌ Audit logging failed:', auditError)
    }
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: errorMessage,
        request_id: crypto.randomUUID()
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

// Register or update user from Sleeper data
async function registerUser(supabase: any, supabaseClient: any, jwt: string | undefined, sleeper_user_id: string, sleeper_username?: string) {
  console.log('🔐 Registering user:', sleeper_user_id)

  if (!jwt) {
    throw new Error('JWT token is required for authentication')
  }

  // Get the authenticated user - passing JWT directly to getUser()
  const { data: { user: authUser }, error: authError } = await supabaseClient.auth.getUser(jwt)
  
  console.log('🔐 Auth check result:', { 
    hasUser: !!authUser, 
    hasError: !!authError,
    errorMessage: authError?.message,
    errorName: authError?.name,
    userId: authUser?.id 
  })
  
  if (authError) {
    console.error('❌ Authentication error details:', JSON.stringify(authError, null, 2))
    
    // If getUser() fails with session missing, it means the JWT token format or validation is wrong
    // Let's try to decode it manually to see what's in it
    console.log('⚠️ Attempting to inspect JWT structure...')
  }
  
  if (!authUser) {
    throw new Error(`User must be authenticated to link Sleeper account. Error: ${authError?.message || 'No user found'}. This likely means the JWT token is invalid or expired.`)
  }
  
  console.log('✅ Authenticated user:', authUser.id)

  // Fetch user data from Sleeper API
  // Try to determine if input is username or user_id, and fetch accordingly
  let sleeperUser: SleeperUser
  let fetchError: string | null = null
  
  // First, try as username (most common)
  const identifier = sleeper_username || sleeper_user_id
  console.log(`🔍 Attempting to fetch Sleeper user: ${identifier}`)
  
  try {
    const userResponse = await fetch(`https://api.sleeper.app/v1/user/${identifier}`)
    if (userResponse.ok) {
      sleeperUser = await userResponse.json()
      console.log(`✅ Found Sleeper user: ${sleeperUser.username} (${sleeperUser.user_id})`)
    } else {
      fetchError = `User not found with identifier: ${identifier}`
      throw new Error(fetchError)
    }
  } catch (error) {
    console.error(`❌ Failed to fetch Sleeper user: ${error}`)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: 'User not found',
        message: `Could not find Sleeper user "${identifier}". Please check the username/ID and try again.`,
        hint: 'Make sure to enter your exact Sleeper username (case-sensitive)'
      }),
      { 
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  // Upsert user in database with supabase_user_id link
  const { data: user, error: userError } = await supabase
    .from('app_users')
    .upsert({
      sleeper_user_id: sleeperUser.user_id,
      sleeper_username: sleeperUser.username,
      display_name: sleeperUser.display_name,
      avatar: sleeperUser.avatar,
      supabase_user_id: authUser.id, // Link to authenticated Supabase user
      last_login: new Date().toISOString()
    }, {
      onConflict: 'sleeper_user_id'
    })
    .select()
    .single()

  if (userError) {
    throw new Error(`Failed to register user: ${userError.message}`)
  }

  console.log('✅ User registered successfully with Supabase auth link')

  // 🔗 Link any existing rosters that belong to this Sleeper user
  // (They may have been synced from a league before this user registered)
  const { data: linkResult, error: linkError } = await supabase
    .rpc('link_user_rosters', {
      p_app_user_id: user.id,
      p_sleeper_user_id: sleeperUser.user_id
    })

  if (linkError) {
    console.warn('⚠️ Failed to link existing rosters:', linkError.message)
  } else if (linkResult > 0) {
    console.log(`🔗 Linked ${linkResult} existing roster(s) to newly registered user`)
  } else {
    console.log('ℹ️ No existing rosters to link (user will create/sync rosters next)')
  }

  return new Response(
    JSON.stringify({
      success: true,
      message: 'User registered successfully',
      user: user,
      timestamp: new Date().toISOString()
    }),
    { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

// Sync user's leagues from Sleeper API
// NEW SCHEMA: Uses leagues table (no user ref) + league_memberships junction table
async function syncUserLeagues(supabase: any, sleeper_user_id: string) {
  console.log('🏈 Syncing leagues for user:', sleeper_user_id)

  // Get current season leagues
  const currentYear = new Date().getFullYear()
  const leaguesResponse = await fetch(`https://api.sleeper.app/v1/user/${sleeper_user_id}/leagues/nfl/${currentYear}`)
  
  if (!leaguesResponse.ok) {
    throw new Error(`Failed to fetch leagues: ${leaguesResponse.statusText}`)
  }

  const leagues: SleeperLeague[] = await leaguesResponse.json()
  console.log(`📊 Found ${leagues.length} leagues for user`)

  // Get user's app_user_id
  const { data: appUser, error: userError } = await supabase
    .from('app_users')
    .select('id')
    .eq('sleeper_user_id', sleeper_user_id)
    .single()

  if (userError || !appUser) {
    throw new Error('User not found. Please register first.')
  }

  // Upsert leagues (one record per league, no user ref)
  const leagueData = leagues.map(league => ({
    sleeper_league_id: league.league_id,
    league_name: league.name,
    season: league.season,
    sport: league.sport,
    league_type: league.settings?.type === 0 ? 'redraft' : league.settings?.type === 1 ? 'keeper' : league.settings?.type === 2 ? 'dynasty' : 'redraft',
    total_rosters: league.total_rosters,
    scoring_settings: league.scoring_settings || {},
    roster_positions: league.roster_positions || [],
    avatar: league.avatar || null,
    status: league.status || null,
    settings: league.settings || {},
    metadata: league.metadata || {},
    last_synced: new Date().toISOString()
  }))

  const { data: upsertedLeagues, error: leaguesError } = await supabase
    .from('leagues')
    .upsert(leagueData, {
      onConflict: 'sleeper_league_id',
      ignoreDuplicates: false
    })
    .select()

  if (leaguesError) {
    throw new Error(`Failed to sync leagues: ${leaguesError.message}`)
  }

  console.log(`✅ Upserted ${upsertedLeagues.length} unique leagues`)

  // Create league memberships (link user to leagues)
  const membershipData = upsertedLeagues.map((league: any) => ({
    app_user_id: appUser.id,
    league_id: league.id,
    is_active: true
  }))

  const { error: membershipError } = await supabase
    .from('league_memberships')
    .upsert(membershipData, {
      onConflict: 'app_user_id,league_id',
      ignoreDuplicates: false
    })

  if (membershipError) {
    throw new Error(`Failed to create league memberships: ${membershipError.message}`)
  }

  console.log(`✅ Created ${membershipData.length} league memberships`)

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Leagues synced successfully',
      leagues_synced: leagues.length,
      timestamp: new Date().toISOString()
    }),
    { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

// Sync ALL rosters for all leagues (multi-user strategy)
// This stores rosters for ALL teams in the league, not just the authenticated user
// NEW SCHEMA: Uses league_memberships to get user's leagues
async function syncUserRosters(supabase: any, sleeper_user_id: string) {
  console.log('🏆 Syncing ALL rosters for user leagues:', sleeper_user_id)

  // Get user and their leagues via league_memberships
  const { data: userData, error: userError } = await supabase
    .from('app_users')
    .select(`
      id,
      league_memberships!inner (
        league_id,
        leagues!inner (
          id,
          sleeper_league_id
        )
      )
    `)
    .eq('sleeper_user_id', sleeper_user_id)
    .single()

  if (userError || !userData) {
    console.error('User query error:', userError)
    throw new Error('User not found. Please register first.')
  }

  console.log('📋 User data:', JSON.stringify(userData, null, 2))

  let totalRostersSynced = 0
  let totalLeaguesProcessed = 0

  // Sync rosters for each league membership
  for (const membership of userData.league_memberships) {
    const league = membership.leagues
    console.log(`📋 Syncing ALL rosters for league: ${league.sleeper_league_id}`)

    // Fetch ALL rosters from Sleeper API
    const rostersResponse = await fetch(`https://api.sleeper.app/v1/league/${league.sleeper_league_id}/rosters`)
    
    if (!rostersResponse.ok) {
      console.warn(`Failed to fetch rosters for league ${league.sleeper_league_id}`)
      continue
    }

    const rosters: SleeperRoster[] = await rostersResponse.json()
    console.log(`📊 Found ${rosters.length} rosters in league ${league.sleeper_league_id}`)

    // Fetch league users to get display names, team names, and avatars
    const usersResponse = await fetch(`https://api.sleeper.app/v1/league/${league.sleeper_league_id}/users`)
    const users: any[] = usersResponse.ok ? await usersResponse.json() : []
    
    // Create lookup maps for display names, team names, and avatars
    const userDisplayNames = new Map(users.map(u => [u.user_id, u.display_name || u.username]))
    const userTeamNames = new Map(users.map(u => [u.user_id, u.metadata?.team_name || '']))
    const userAvatarIds = new Map(users.map(u => [u.user_id, u.avatar || null]))
    const teamAvatarUrls = new Map(users.map(u => [u.user_id, u.metadata?.avatar || null]))
    console.log(`👥 Fetched ${users.length} user profiles (display names, team names, avatars)`)

    // Store ALL rosters (multi-user strategy)
    for (const roster of rosters) {
      // Check if this roster's owner is registered in our system
      console.log(`🔍 Looking for app_user with sleeper_user_id: ${roster.owner_id}`)
      const { data: rosterOwner, error: ownerError } = await supabase
        .from('app_users')
        .select('id')
        .eq('sleeper_user_id', roster.owner_id)
        .maybeSingle()
      
      if (ownerError) {
        console.log(`❌ Error querying for owner ${roster.owner_id}:`, ownerError)
      }
      if (rosterOwner) {
        console.log(`✅ Found app_user ${rosterOwner.id} for sleeper_user_id ${roster.owner_id}`)
      } else {
        console.log(`⚠️  No app_user found for sleeper_user_id ${roster.owner_id} - will set app_user_id to NULL`)
      }

      // Extract team name from users metadata (metadata.team_name like "GlenSuckIt Rangers")
      const teamName = userTeamNames.get(roster.owner_id) || null
      if (teamName) {
        console.log(`📝 Team name for roster ${roster.roster_id}: "${teamName}"`)
      }

      // Get owner display name from users lookup
      const ownerDisplayName = userDisplayNames.get(roster.owner_id) || null
      
      // Get avatar information
      const avatarId = userAvatarIds.get(roster.owner_id) || null
      const teamAvatarUrl = teamAvatarUrls.get(roster.owner_id) || null
      
      if (avatarId) {
        console.log(`🎨 User avatar ID for roster ${roster.roster_id}: ${avatarId}`)
      }
      if (teamAvatarUrl) {
        console.log(`🖼️  Team avatar URL for roster ${roster.roster_id}: ${teamAvatarUrl}`)
      }

      // Upsert roster data
      // If owner is registered: link immediately (app_user_id set)
      // If owner not registered: store with app_user_id=NULL (will link when they register)
      const { error: rosterError } = await supabase
        .from('user_rosters')
        .upsert({
          app_user_id: rosterOwner?.id || null,  // NULL if user not registered yet
          league_id: league.id,  // References the leagues table now
          sleeper_owner_id: roster.owner_id,  // Always store Sleeper owner ID (used to template avatar URL)
          sleeper_roster_id: roster.roster_id,
          team_name: teamName,  // Team name from user metadata
          owner_display_name: ownerDisplayName,  // Owner display name
          avatar_id: avatarId,  // User avatar ID from Sleeper
          team_avatar_url: teamAvatarUrl,  // Team-specific avatar URL from metadata
          player_ids: roster.players || [],
          starters: roster.starters || [],
          reserves: roster.reserve || [],
          taxi: roster.taxi || [],
          settings: roster.settings || {},
          last_synced: new Date().toISOString()
        }, {
          onConflict: 'league_id,sleeper_owner_id'  // Updated constraint
        })

      if (rosterError) {
        console.error(`Failed to sync roster ${roster.roster_id}:`, rosterError)
        continue
      }

      totalRostersSynced++
    }

    totalLeaguesProcessed++
  }

  console.log(`✅ Synced ${totalRostersSynced} rosters across ${totalLeaguesProcessed} leagues`)

  return new Response(
    JSON.stringify({
      success: true,
      message: 'All rosters synced successfully (multi-user)',
      leagues_processed: totalLeaguesProcessed,
      rosters_synced: totalRostersSynced,
      timestamp: new Date().toISOString()
    }),
    { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

// Full sync: register user + sync leagues + sync rosters
async function fullUserSync(supabase: any, supabaseClient: any, jwt: string | undefined, sleeper_user_id: string, sleeper_username?: string) {
  console.log('🔄 Starting full sync for user:', sleeper_user_id)

  // Step 1: Register user
  await registerUser(supabase, supabaseClient, jwt, sleeper_user_id, sleeper_username)
  
  // Step 2: Sync leagues
  await syncUserLeagues(supabase, sleeper_user_id)
  
  // Step 3: Sync rosters
  await syncUserRosters(supabase, sleeper_user_id)

  console.log('🎉 Full sync completed successfully')

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Full user sync completed successfully',
      timestamp: new Date().toISOString()
    }),
    { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

// Get all unique player IDs from rosters in user's leagues
// This is used for targeted embedding (only embed rostered players)
// NEW SCHEMA: Uses league_memberships to get user's leagues
async function getRosteredPlayers(supabase: any, sleeper_user_id: string) {
  console.log('📊 Getting rostered players for user:', sleeper_user_id)

  // Get user's league IDs via league_memberships
  const { data: memberships, error: membershipError } = await supabase
    .from('league_memberships')
    .select('league_id, app_users!inner(sleeper_user_id)')
    .eq('app_users.sleeper_user_id', sleeper_user_id)
    .eq('is_active', true)

  if (membershipError || !memberships) {
    throw new Error('User not found or has no league memberships. Please register first.')
  }

  const leagueIds = memberships.map((m: any) => m.league_id)
  console.log(`🏈 Found ${leagueIds.length} league memberships`)
  
  // Get all rosters for user's leagues
  const { data: rosters, error: rostersError } = await supabase
    .from('user_rosters')
    .select('player_ids')
    .in('league_id', leagueIds)

  if (rostersError) {
    throw new Error(`Failed to fetch rosters: ${rostersError.message}`)
  }

  // Extract unique player IDs
  const playerIdsSet = new Set<string>()
  for (const roster of rosters) {
    if (roster.player_ids && Array.isArray(roster.player_ids)) {
      roster.player_ids.forEach((id: string) => playerIdsSet.add(id))
    }
  }

  const uniquePlayerIds = Array.from(playerIdsSet)
  console.log(`✅ Found ${uniquePlayerIds.length} unique rostered players across ${rosters.length} rosters`)

  return new Response(
    JSON.stringify({
      success: true,
      player_count: uniquePlayerIds.length,
      roster_count: rosters.length,
      league_count: leagueIds.length,
      player_ids: uniquePlayerIds,
      timestamp: new Date().toISOString()
    }),
    { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/user-sync' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
