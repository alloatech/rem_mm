// Simple Data Ingestion with Status Polling
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { logSecurityEvent } from '../_shared/auth.ts'

console.log("simple-ingestion function loaded")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// In-memory status tracking (for demo - in production use database)
let currentStatus = {
  phase: 'idle',
  step: '',
  progress: 0,
  total: 0,
  message: 'Ready to start',
  startTime: null as Date | null,
  lastUpdate: new Date()
}

function updateStatus(update: Partial<typeof currentStatus>) {
  currentStatus = { 
    ...currentStatus, 
    ...update, 
    lastUpdate: new Date() 
  }
  console.log(`📊 Status: ${currentStatus.message} (${currentStatus.progress}/${currentStatus.total})`)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const url = new URL(req.url)
  
  // Status endpoint - just return current status
  if (url.pathname.endsWith('/status')) {
    return new Response(JSON.stringify({
      success: true,
      status: currentStatus,
      progressPercent: currentStatus.total > 0 ? Math.round((currentStatus.progress / currentStatus.total) * 100) : 0,
      elapsed: currentStatus.startTime ? Date.now() - currentStatus.startTime.getTime() : 0
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Main ingestion endpoint
  try {
    const { limit = 25, test_mode = true, gemini_api_key } = await req.json().catch(() => ({}))

    updateStatus({
      phase: 'starting',
      message: '🚀 Initializing data ingestion...',
      startTime: new Date(),
      progress: 0,
      total: 0
    })

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 🔐 AUDIT: Data ingestion started
    await logSecurityEvent(
      supabase,
      'data_ingestion_start',
      'system',
      { limit, test_mode, function: 'simple-ingestion' },
      req
    )

    // Step 1: Fetch data with status update
    updateStatus({
      phase: 'fetching',
      message: '📥 Fetching players from Sleeper API...'
    })

    const sleeperResponse = await fetch('https://api.sleeper.app/v1/players/nfl')
    const playersData = await sleeperResponse.json()
    const totalPlayers = Object.keys(playersData).length

    updateStatus({
      message: `✅ Fetched ${totalPlayers} players from Sleeper`,
      total: totalPlayers
    })

    // Step 2: Filter players
    updateStatus({
      phase: 'filtering',
      message: '🔍 Filtering fantasy-relevant players...'
    })

    const activePlayerIds = Object.keys(playersData).filter(id => {
      const player = playersData[id]
      return player.position && 
             player.team &&  
             ['QB', 'RB', 'WR', 'TE', 'K'].includes(player.position) && 
             (player.status === 'Active' || !player.status)
    })

    const playerIdsToProcess = test_mode 
      ? activePlayerIds.slice(0, Math.min(limit, activePlayerIds.length))
      : activePlayerIds

    updateStatus({
      message: `🎯 Selected ${playerIdsToProcess.length} players for processing`,
      total: playerIdsToProcess.length
    })

    // Step 3: Sync players to database with progress updates
    updateStatus({
      phase: 'syncing',
      message: '💾 Syncing players to database...'
    })

    let syncedCount = 0
    const batchSize = 500

    for (let i = 0; i < totalPlayers; i += batchSize) {
      const playerBatch = Object.entries(playersData).slice(i, i + batchSize)
      
      const batchData = playerBatch.map(([playerId, player]) => ({
        player_id: playerId,
        full_name: (player as any).full_name,
        position: (player as any).position,
        team: (player as any).team,
        status: (player as any).status,
        active: (player as any).active,
        depth_chart_order: (player as any).depth_chart_order,
        injury_status: (player as any).injury_status,
        age: (player as any).age,
        college: (player as any).college,
        years_exp: (player as any).years_exp,
        raw_data: player
      }))

      await supabase.from('players_raw').upsert(batchData, { onConflict: 'player_id' })
      
      syncedCount += batchData.length
      updateStatus({
        progress: syncedCount,
        total: totalPlayers,
        message: `💾 Synced ${syncedCount}/${totalPlayers} players to database`
      })

      // Brief pause to allow status polling
      await new Promise(resolve => setTimeout(resolve, 100))
    }

    // Step 4: Generate embeddings (if API key provided)
    if (gemini_api_key) {
      updateStatus({
        phase: 'embedding',
        message: '🧠 Generating embeddings for key players...',
        progress: 0,
        total: playerIdsToProcess.length
      })

      let embeddedCount = 0
      const embedBatchSize = 3

      for (let i = 0; i < playerIdsToProcess.length; i += embedBatchSize) {
        const batch = playerIdsToProcess.slice(i, i + embedBatchSize)
        
        for (const playerId of batch) {
          try {
            const player = playersData[playerId]
            
            // Simple embedding logic for key players
            if ((player as any).position && ['QB', 'RB', 'WR', 'TE'].includes((player as any).position) && (player as any).team) {
              
              updateStatus({
                progress: embeddedCount,
                message: `🧠 Embedding: ${(player as any).full_name} (${(player as any).position})`
              })

              const content = `Player: ${(player as any).full_name}, Position: ${(player as any).position}, Team: ${(player as any).team}`
              
              const embeddingResponse = await fetch(
                `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${gemini_api_key}`,
                {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                    model: "models/text-embedding-004",
                    content: { parts: [{ text: content }] }
                  })
                }
              )

              if (embeddingResponse.ok) {
                const embeddingData = await embeddingResponse.json()
                const embedding = embeddingData.embedding.values

                await supabase.from('player_embeddings_selective').upsert({
                  player_id: playerId,
                  content,
                  embedding: `[${embedding.join(',')}]`,
                  embed_reason: 'fantasy_relevant',
                  embed_priority: 10
                }, { onConflict: 'player_id' })

                embeddedCount++
              }
            }
          } catch (error) {
            console.error(`Error processing ${playerId}:`, error)
          }
        }

        // Rate limiting pause
        await new Promise(resolve => setTimeout(resolve, 1500))
      }

      updateStatus({
        phase: 'complete',
        message: `🎉 Complete! Synced ${syncedCount} players, embedded ${embeddedCount}`,
        progress: embeddedCount,
        total: embeddedCount
      })

      // 🔐 AUDIT: Data ingestion completed
      await logSecurityEvent(
        supabase,
        'data_ingestion_complete',
        'system',
        { 
          totalPlayers: syncedCount,
          embeddedPlayers: embeddedCount,
          cost: (embeddedCount * 0.0001).toFixed(4),
          test_mode
        },
        req
      )

      return new Response(JSON.stringify({
        success: true,
        message: "Data ingestion completed with embeddings",
        stats: {
          totalPlayers: syncedCount,
          embeddedPlayers: embeddedCount,
          cost: (embeddedCount * 0.0001).toFixed(4)
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })

    } else {
      updateStatus({
        phase: 'complete',
        message: `✅ Complete! Synced ${syncedCount} players (no embeddings - no API key)`,
        progress: syncedCount,
        total: syncedCount
      })

      return new Response(JSON.stringify({
        success: true,
        message: "Data sync completed without embeddings",
        stats: { totalPlayers: syncedCount, embeddedPlayers: 0 }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

  } catch (error) {
    updateStatus({
      phase: 'error',
      message: `❌ Error: ${(error as Error).message}`
    })

    return new Response(JSON.stringify({
      success: false,
      error: (error as Error).message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})