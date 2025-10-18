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
  roster_positions: string[]
  total_rosters: number
}

interface SleeperRoster {
  roster_id: number
  owner_id: string
  players: string[]
  starters: string[]
  reserve?: string[]
  taxi?: string[]
  settings: any
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

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // Use service role for full access
    const supabase = createClient(supabaseUrl, supabaseKey)

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
        result = await registerUser(supabase, sleeper_user_id, sleeper_username)
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
        result = await fullUserSync(supabase, sleeper_user_id, sleeper_username)
        await logSecurityEvent(supabase, 'full_sync_complete', sleeper_user_id, { action }, req)
        return result
      
      default:
        await logSecurityEvent(supabase, 'user_sync_invalid_action', sleeper_user_id, { action }, req)
        return new Response(
          JSON.stringify({ error: 'Invalid action. Use: register_user, sync_leagues, sync_rosters, or full_sync' }),
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
async function registerUser(supabase: any, sleeper_user_id: string, sleeper_username?: string) {
  console.log('🔐 Registering user:', sleeper_user_id)

  // Fetch user data from Sleeper API
  let sleeperUser: SleeperUser
  
  if (sleeper_username) {
    const userResponse = await fetch(`https://api.sleeper.app/v1/user/${sleeper_username}`)
    if (!userResponse.ok) {
      throw new Error(`Failed to fetch user by username: ${userResponse.statusText}`)
    }
    sleeperUser = await userResponse.json()
  } else {
    const userResponse = await fetch(`https://api.sleeper.app/v1/user/${sleeper_user_id}`)
    if (!userResponse.ok) {
      throw new Error(`Failed to fetch user by ID: ${userResponse.statusText}`)
    }
    sleeperUser = await userResponse.json()
  }

  // Upsert user in database
  const { data: user, error: userError } = await supabase
    .from('app_users')
    .upsert({
      sleeper_user_id: sleeperUser.user_id,
      sleeper_username: sleeperUser.username,
      display_name: sleeperUser.display_name,
      avatar: sleeperUser.avatar,
      last_login: new Date().toISOString()
    }, {
      onConflict: 'sleeper_user_id'
    })
    .select()
    .single()

  if (userError) {
    throw new Error(`Failed to register user: ${userError.message}`)
  }

  console.log('✅ User registered successfully')

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

  const leagueData = leagues.map(league => ({
    app_user_id: appUser.id,
    sleeper_league_id: league.league_id,
    league_name: league.name,
    season: league.season,
    sport: league.sport,
    league_type: league.settings?.type || 'redraft',
    total_rosters: league.total_rosters,
    scoring_settings: league.settings || {},
    roster_positions: league.roster_positions || [],
    last_synced: new Date().toISOString()
  }))

  // Upsert leagues
  const { error: leaguesError } = await supabase
    .from('user_leagues')
    .upsert(leagueData, {
      onConflict: 'app_user_id,sleeper_league_id'
    })

  if (leaguesError) {
    throw new Error(`Failed to sync leagues: ${leaguesError.message}`)
  }

  console.log('✅ Leagues synced successfully')

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

// Sync user's rosters for all their leagues
async function syncUserRosters(supabase: any, sleeper_user_id: string) {
  console.log('🏆 Syncing rosters for user:', sleeper_user_id)

  // Get user and their leagues
  const { data: userData, error: userError } = await supabase
    .from('app_users')
    .select(`
      id,
      user_leagues (
        id,
        sleeper_league_id
      )
    `)
    .eq('sleeper_user_id', sleeper_user_id)
    .single()

  if (userError || !userData) {
    throw new Error('User not found. Please register first.')
  }

  let totalRostersSynced = 0

  // Sync rosters for each league
  for (const league of userData.user_leagues) {
    console.log(`📋 Syncing roster for league: ${league.sleeper_league_id}`)

    // Fetch rosters from Sleeper API
    const rostersResponse = await fetch(`https://api.sleeper.app/v1/league/${league.sleeper_league_id}/rosters`)
    
    if (!rostersResponse.ok) {
      console.warn(`Failed to fetch rosters for league ${league.sleeper_league_id}`)
      continue
    }

    const rosters: SleeperRoster[] = await rostersResponse.json()
    const userRoster = rosters.find(roster => roster.owner_id === sleeper_user_id)

    if (!userRoster) {
      console.warn(`User not found in league ${league.sleeper_league_id}`)
      continue
    }

    // Upsert roster data
    const { error: rosterError } = await supabase
      .from('user_rosters')
      .upsert({
        app_user_id: userData.id,
        league_id: league.id,
        sleeper_roster_id: userRoster.roster_id,
        player_ids: userRoster.players || [],
        starters: userRoster.starters || [],
        reserves: userRoster.reserve || [],
        taxi: userRoster.taxi || [],
        settings: userRoster.settings || {},
        last_synced: new Date().toISOString()
      }, {
        onConflict: 'app_user_id,league_id'
      })

    if (rosterError) {
      console.error(`Failed to sync roster for league ${league.sleeper_league_id}:`, rosterError)
      continue
    }

    totalRostersSynced++
  }

  console.log(`✅ Synced ${totalRostersSynced} rosters successfully`)

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Rosters synced successfully',
      rosters_synced: totalRostersSynced,
      timestamp: new Date().toISOString()
    }),
    { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

// Full sync: register user + sync leagues + sync rosters
async function fullUserSync(supabase: any, sleeper_user_id: string, sleeper_username?: string) {
  console.log('🔄 Starting full sync for user:', sleeper_user_id)

  // Step 1: Register user
  await registerUser(supabase, sleeper_user_id, sleeper_username)
  
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

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/user-sync' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
