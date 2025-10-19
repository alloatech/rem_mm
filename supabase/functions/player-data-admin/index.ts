// Player Data Admin - Import/Export and Management
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { logSecurityEvent, verifyAdminAccess } from '../_shared/auth.ts'

console.log("player-data-admin function loaded")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PlayerStats {
  totalPlayers: number
  byPosition: Record<string, number>
  byTeam: Record<string, number>
  byStatus: Record<string, number>
  activeCount: number
  injuredCount: number
  lastSyncTime: string | null
}

interface EmbeddingStats {
  totalEmbedded: number
  byReason: Record<string, number>
  byPriority: Record<string, number>
  averageContentLength: number
  oldestEmbedding: string | null
  newestEmbedding: string | null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    // Get auth token
    const authHeader = req.headers.get('Authorization')
    const jwt = authHeader?.replace('Bearer ', '')
    
    // Create clients
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } }
    })
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    // Verify admin access
    const adminCheck = await verifyAdminAccess(supabaseClient, supabase, jwt!)
    if (!adminCheck.isAdmin) {
      return new Response(
        JSON.stringify({ success: false, error: 'Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { action, data } = await req.json()
    console.log(`📊 Admin action: ${action}`)

    // Log admin action
    await logSecurityEvent(
      supabase,
      'admin_player_data_action',
      adminCheck.sleeperUserId!,
      { action, dataSize: data ? JSON.stringify(data).length : 0 },
      req
    )

    switch (action) {
      case 'get_stats': {
        // Get comprehensive statistics about player data
        const [playersStats, embeddingsStats] = await Promise.all([
          getPlayerStats(supabase),
          getEmbeddingStats(supabase)
        ])

        return new Response(
          JSON.stringify({
            success: true,
            players: playersStats,
            embeddings: embeddingsStats,
            timestamp: new Date().toISOString()
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'export_players': {
        // Export all player data
        const { data: players, error } = await supabase
          .from('players_raw')
          .select('*')
          .order('full_name')

        if (error) throw error

        return new Response(
          JSON.stringify({
            success: true,
            count: players?.length || 0,
            data: players,
            exportedAt: new Date().toISOString()
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'export_embeddings': {
        // Export all embeddings data
        const { data: embeddings, error } = await supabase
          .from('player_embeddings_selective')
          .select('*')
          .order('embed_priority', { ascending: false })

        if (error) throw error

        return new Response(
          JSON.stringify({
            success: true,
            count: embeddings?.length || 0,
            data: embeddings,
            exportedAt: new Date().toISOString()
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'import_players': {
        // Import player data (upsert)
        if (!data || !Array.isArray(data)) {
          throw new Error('Invalid data format - expected array of players')
        }

        console.log(`📥 Importing ${data.length} players...`)
        
        const { data: result, error } = await supabase
          .from('players_raw')
          .upsert(data, { onConflict: 'player_id' })

        if (error) throw error

        return new Response(
          JSON.stringify({
            success: true,
            imported: data.length,
            message: `Successfully imported ${data.length} players`,
            timestamp: new Date().toISOString()
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'import_embeddings': {
        // Import embeddings data (upsert)
        if (!data || !Array.isArray(data)) {
          throw new Error('Invalid data format - expected array of embeddings')
        }

        console.log(`📥 Importing ${data.length} embeddings...`)
        
        // Remove id field for insert (let DB auto-generate)
        const embeddingsToInsert = data.map(({ id, ...rest }) => rest)
        
        const { data: result, error } = await supabase
          .from('player_embeddings_selective')
          .upsert(embeddingsToInsert, { onConflict: 'player_id' })

        if (error) throw error

        return new Response(
          JSON.stringify({
            success: true,
            imported: data.length,
            message: `Successfully imported ${data.length} embeddings`,
            timestamp: new Date().toISOString()
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'fetch_sleeper_data': {
        // Fetch fresh data from Sleeper API
        console.log('📥 Fetching fresh player data from Sleeper...')
        
        const sleeperResponse = await fetch('https://api.sleeper.app/v1/players/nfl')
        if (!sleeperResponse.ok) {
          throw new Error(`Sleeper API error: ${sleeperResponse.status}`)
        }
        
        const playersData = await sleeperResponse.json()
        const totalPlayers = Object.keys(playersData).length
        
        console.log(`✅ Fetched ${totalPlayers} players from Sleeper`)
        
        // Transform Sleeper data to our schema
        const playersArray = Object.entries(playersData).map(([id, player]: [string, any]) => ({
          player_id: id,
          full_name: player.full_name || `${player.first_name || ''} ${player.last_name || ''}`.trim(),
          first_name: player.first_name,
          last_name: player.last_name,
          position: player.position,
          team: player.team,
          team_abbr: player.team,
          status: player.status,
          active: player.active || player.status === 'Active',
          depth_chart_position: player.depth_chart_position,
          depth_chart_order: player.depth_chart_order,
          injury_status: player.injury_status,
          injury_notes: player.injury_notes,
          injury_body_part: player.injury_body_part,
          injury_start_date: player.injury_start_date ? new Date(player.injury_start_date).toISOString() : null,
          practice_participation: player.practice_participation,
          practice_description: player.practice_description,
          age: player.age,
          height: player.height,
          weight: player.weight,
          college: player.college,
          years_exp: player.years_exp,
          number: player.number,
          rookie_year: player.rookie_year,
          espn_id: player.espn_id,
          yahoo_id: player.yahoo_id,
          fantasy_data_id: player.fantasy_data_id,
          raw_data: player,
          news_updated: player.news_updated,
          last_synced: new Date().toISOString()
        }))
        
        // Filter to fantasy-relevant players
        const fantasyPositions = ['QB', 'RB', 'WR', 'TE', 'K', 'DEF']
        const fantasyPlayers = playersArray.filter(p => 
          p.position && fantasyPositions.includes(p.position) && p.active
        )
        
        console.log(`🏈 ${fantasyPlayers.length} fantasy-relevant players`)
        
        // Store in database
        const { error: upsertError } = await supabase
          .from('players_raw')
          .upsert(fantasyPlayers, { onConflict: 'player_id' })
        
        if (upsertError) throw upsertError
        
        return new Response(
          JSON.stringify({
            success: true,
            totalFetched: totalPlayers,
            fantasyRelevant: fantasyPlayers.length,
            stored: fantasyPlayers.length,
            message: `Successfully fetched and stored ${fantasyPlayers.length} fantasy players`,
            timestamp: new Date().toISOString()
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'clear_players': {
        // Clear all player data (destructive!)
        const { confirm } = data || {}
        if (confirm !== 'DELETE_ALL_PLAYERS') {
          throw new Error('Confirmation required: send {confirm: "DELETE_ALL_PLAYERS"}')
        }

        const { error } = await supabase
          .from('players_raw')
          .delete()
          .neq('player_id', '')  // Delete all

        if (error) throw error

        return new Response(
          JSON.stringify({
            success: true,
            message: 'All player data cleared',
            timestamp: new Date().toISOString()
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'clear_embeddings': {
        // Clear all embeddings (destructive!)
        const { confirm } = data || {}
        if (confirm !== 'DELETE_ALL_EMBEDDINGS') {
          throw new Error('Confirmation required: send {confirm: "DELETE_ALL_EMBEDDINGS"}')
        }

        const { error } = await supabase
          .from('player_embeddings_selective')
          .delete()
          .neq('id', 0)  // Delete all

        if (error) throw error

        return new Response(
          JSON.stringify({
            success: true,
            message: 'All embeddings cleared',
            timestamp: new Date().toISOString()
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      default:
        return new Response(
          JSON.stringify({
            success: false,
            error: `Unknown action: ${action}`,
            availableActions: [
              'get_stats',
              'export_players',
              'export_embeddings',
              'import_players',
              'import_embeddings',
              'fetch_sleeper_data',
              'clear_players',
              'clear_embeddings'
            ]
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }

  } catch (error) {
    console.error('❌ Error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error'
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Helper function to get player statistics
async function getPlayerStats(supabase: any): Promise<PlayerStats> {
  const { data: players, error } = await supabase
    .from('players_raw')
    .select('position, team, status, active, injury_status, last_synced')

  if (error) throw error

  const stats: PlayerStats = {
    totalPlayers: players?.length || 0,
    byPosition: {},
    byTeam: {},
    byStatus: {},
    activeCount: 0,
    injuredCount: 0,
    lastSyncTime: null
  }

  let latestSync: Date | null = null

  players?.forEach((player: any) => {
    // Position counts
    if (player.position) {
      stats.byPosition[player.position] = (stats.byPosition[player.position] || 0) + 1
    }

    // Team counts
    if (player.team) {
      stats.byTeam[player.team] = (stats.byTeam[player.team] || 0) + 1
    }

    // Status counts
    if (player.status) {
      stats.byStatus[player.status] = (stats.byStatus[player.status] || 0) + 1
    }

    // Active count
    if (player.active) {
      stats.activeCount++
    }

    // Injured count
    if (player.injury_status) {
      stats.injuredCount++
    }

    // Latest sync time
    if (player.last_synced) {
      const syncDate = new Date(player.last_synced)
      if (!latestSync || syncDate > latestSync) {
        latestSync = syncDate
      }
    }
  })

  stats.lastSyncTime = latestSync?.toISOString() || null

  return stats
}

// Helper function to get embedding statistics
async function getEmbeddingStats(supabase: any): Promise<EmbeddingStats> {
  const { data: embeddings, error } = await supabase
    .from('player_embeddings_selective')
    .select('embed_reason, embed_priority, content, embedding_created')

  if (error) throw error

  const stats: EmbeddingStats = {
    totalEmbedded: embeddings?.length || 0,
    byReason: {},
    byPriority: {},
    averageContentLength: 0,
    oldestEmbedding: null,
    newestEmbedding: null
  }

  let totalContentLength = 0
  let oldest: Date | null = null
  let newest: Date | null = null

  embeddings?.forEach((emb: any) => {
    // Reason counts
    if (emb.embed_reason) {
      stats.byReason[emb.embed_reason] = (stats.byReason[emb.embed_reason] || 0) + 1
    }

    // Priority counts
    const priority = emb.embed_priority || 1
    stats.byPriority[priority] = (stats.byPriority[priority] || 0) + 1

    // Content length
    if (emb.content) {
      totalContentLength += emb.content.length
    }

    // Oldest/newest
    if (emb.embedding_created) {
      const created = new Date(emb.embedding_created)
      if (!oldest || created < oldest) oldest = created
      if (!newest || created > newest) newest = created
    }
  })

  stats.averageContentLength = embeddings?.length 
    ? Math.round(totalContentLength / embeddings.length) 
    : 0
  stats.oldestEmbedding = oldest?.toISOString() || null
  stats.newestEmbedding = newest?.toISOString() || null

  return stats
}
