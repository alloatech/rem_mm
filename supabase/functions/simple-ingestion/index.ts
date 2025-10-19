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
    const { 
      limit = 25, 
      test_mode = true, 
      gemini_api_key,
      player_ids = null  // NEW: Accept specific player IDs for targeted embedding
    } = await req.json().catch(() => ({}))

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
      { limit, test_mode, targeted_players: !!player_ids, function: 'simple-ingestion' },
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

    let playerIdsToProcess: string[]

    if (player_ids && Array.isArray(player_ids) && player_ids.length > 0) {
      // 🎯 TARGETED MODE: Use specific player IDs (rostered players only)
      playerIdsToProcess = player_ids.filter(id => playersData[id])
      updateStatus({
        message: `🎯 TARGETED MODE: ${playerIdsToProcess.length} specific players selected (rostered players)`,
        total: playerIdsToProcess.length
      })
    } else {
      // 🌐 BROAD MODE: Filter fantasy-relevant players
      const activePlayerIds = Object.keys(playersData).filter(id => {
        const player = playersData[id]
        return player.position && 
               player.team &&  
               ['QB', 'RB', 'WR', 'TE', 'K'].includes(player.position) && 
               (player.status === 'Active' || !player.status)
      })

      playerIdsToProcess = test_mode 
        ? activePlayerIds.slice(0, Math.min(limit, activePlayerIds.length))
        : activePlayerIds

      updateStatus({
        message: `🎯 Selected ${playerIdsToProcess.length} players for processing`,
        total: playerIdsToProcess.length
      })
    }

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
        message: '🧠 Checking which players need embedding...',
        progress: 0,
        total: playerIdsToProcess.length
      })

      // 💰 COST OPTIMIZATION: Fetch existing embeddings first
      const { data: existingEmbeddings } = await supabase
        .from('player_embeddings_selective')
        .select('player_id, profile_hash')

      const existingMap = new Map(
        existingEmbeddings?.map((e: any) => [e.player_id, e.profile_hash]) || []
      )

      let embeddedCount = 0
      let skippedCount = 0
      let failedCount = 0
      const failedPlayers: string[] = []
      const embedBatchSize = 10  // Increased from 3 - Gemini allows 60/min

      for (let i = 0; i < playerIdsToProcess.length; i += embedBatchSize) {
        const batch = playerIdsToProcess.slice(i, i + embedBatchSize)
        
        // Process batch concurrently using Promise.allSettled
        const batchResults = await Promise.allSettled(
          batch.map(async (playerId) => {
            const player = playersData[playerId]
            
            // Simple embedding logic for key players
            if (!(player as any).position || !['QB', 'RB', 'WR', 'TE'].includes((player as any).position) || !(player as any).team) {
              return { status: 'irrelevant', playerId }
            }
            
            // 🔑 Generate hash from stable fields only
            const profileData = {
              name: (player as any).full_name || '',
              position: (player as any).position || '',
              team: (player as any).team || '',
              college: (player as any).college || '',
              height: (player as any).height || '',
              weight: (player as any).weight || '',
              birth_date: (player as any).birth_date || ''
            }
            const profileHash = await crypto.subtle.digest(
              'SHA-256',
              new TextEncoder().encode(JSON.stringify(profileData))
            )
            const hashHex = Array.from(new Uint8Array(profileHash))
              .map(b => b.toString(16).padStart(2, '0'))
              .join('')

            // 💰 Check if embedding exists with same profile
            const existingHash = existingMap.get(playerId)
            if (existingHash === hashHex) {
              return { status: 'skipped', playerName: (player as any).full_name }
            }

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

            if (!embeddingResponse.ok) {
              throw new Error(`Gemini API error: ${embeddingResponse.status}`)
            }

            const embeddingData = await embeddingResponse.json()
            const embedding = embeddingData.embedding.values

            const { error: insertError } = await supabase.from('player_embeddings_selective').upsert({
              player_id: playerId,
              content,
              embedding: `[${embedding.join(',')}]`,
              embed_reason: 'fantasy_relevant',
              embed_priority: 10,
              profile_hash: hashHex
            }, { onConflict: 'player_id' })

            if (insertError) {
              throw new Error(`DB insert error: ${insertError.message}`)
            }

            return { status: 'success', playerName: (player as any).full_name, existingHash }
          })
        )

        // Process results
        for (let j = 0; j < batchResults.length; j++) {
          const result = batchResults[j]
          const playerId = batch[j]
          const player = playersData[playerId]
          const playerName = (player as any)?.full_name || playerId

          if (result.status === 'fulfilled') {
            const value = result.value as any
            if (value.status === 'success') {
              embeddedCount++
              updateStatus({
                progress: embeddedCount + skippedCount + failedCount,
                message: `✅ ${value.playerName} (${value.existingHash ? 'updated' : 'new'})`
              })
            } else if (value.status === 'skipped') {
              skippedCount++
              updateStatus({
                progress: embeddedCount + skippedCount + failedCount,
                message: `⏭️  ${value.playerName} (unchanged)`
              })
            }
          } else {
            failedCount++
            failedPlayers.push(`${playerName} (${playerId})`)
            updateStatus({
              progress: embeddedCount + skippedCount + failedCount,
              message: `❌ ${playerName} - ${result.reason}`
            })
          }
        }

        // Rate limiting: ~10 requests per batch, 60/min max = 6 batches/min = 10s between batches
        // Use 10s pause to stay safely under limit
        if (i + embedBatchSize < playerIdsToProcess.length) {
          await new Promise(resolve => setTimeout(resolve, 10000))
        }
      }

      const totalProcessed = embeddedCount + skippedCount + failedCount
      const hasFailures = failedCount > 0
      
      updateStatus({
        phase: hasFailures ? 'complete_with_errors' : 'complete',
        message: hasFailures 
          ? `⚠️  Complete with errors! Synced ${syncedCount}, embedded ${embeddedCount}, skipped ${skippedCount}, failed ${failedCount}`
          : `🎉 Complete! Synced ${syncedCount}, embedded ${embeddedCount}, skipped ${skippedCount} unchanged`,
        progress: totalProcessed,
        total: totalProcessed
      })

      // 🔐 AUDIT: Data ingestion completed
      await logSecurityEvent(
        supabase,
        'data_ingestion_complete',
        'system',
        { 
          totalPlayers: syncedCount,
          embeddedPlayers: embeddedCount,
          skippedPlayers: skippedCount,
          failedPlayers: failedCount,
          savingsPercent: totalProcessed > 0 ? Math.round((skippedCount / totalProcessed) * 100) : 0,
          actualCost: (embeddedCount * 0.0001).toFixed(4),
          savedCost: (skippedCount * 0.0001).toFixed(4),
          hasErrors: hasFailures,
          test_mode
        },
        req
      )

      return new Response(JSON.stringify({
        success: !hasFailures, // Only success if no failures
        message: hasFailures 
          ? `Data ingestion completed with ${failedCount} errors. Re-run to retry failed players.`
          : "Data ingestion completed with embeddings",
        stats: {
          totalPlayers: syncedCount,
          embeddedPlayers: embeddedCount,
          skippedPlayers: skippedCount,
          failedPlayers: failedCount,
          cost: (embeddedCount * 0.0001).toFixed(4),
          savedCost: (skippedCount * 0.0001).toFixed(4)
        },
        ...(failedCount > 0 && { 
          failures: failedPlayers,
          retryAdvice: "Re-run the script to automatically retry only the failed players."
        })
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