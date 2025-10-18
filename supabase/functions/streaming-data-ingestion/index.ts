// Streaming Data Ingestion with Real-Time Progress Updates
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

console.log("streaming-data-ingestion function loaded")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Streaming progress updates
function sendProgressUpdate(controller: ReadableStreamDefaultController, update: any) {
  const data = `data: ${JSON.stringify(update)}\n\n`
  controller.enqueue(new TextEncoder().encode(data))
}

// Generate embedding (same as before but with progress callbacks)
async function generateEmbedding(text: string, apiKey: string): Promise<number[]> {
  const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: "models/text-embedding-004",
      content: { parts: [{ text }] }
    })
  })

  if (!response.ok) {
    throw new Error(`Gemini API error: ${response.status}`)
  }

  const data = await response.json()
  return data.embedding?.values || []
}

// Format player chunk for stable identity
function formatPlayerChunk(player: any, playerId: string): string {
  const playerName = player.full_name || `${player.first_name || ''} ${player.last_name || ''}`.trim()
  const position = player.position || 'Unknown'
  const team = player.team || 'FA'
  
  let context = `Player: ${playerName}, Position: ${position}, Team: ${team}`
  
  if (player.college) context += `, College: ${player.college}`
  if (player.years_exp !== undefined) context += `, Experience: ${player.years_exp} years`
  if (player.age) context += `, Age: ${player.age}`
  if (player.metadata?.rookie_year === '2024') context += `, Rookie Year: 2024`
  
  context += `. Fantasy football ${position} for the ${team} team.`
  return context
}

// Check if player should get embedding
function shouldEmbed(player: any): { should: boolean, reason: string, priority: number } {
  if (player.position && ['QB', 'RB', 'WR', 'TE'].includes(player.position) && 
      player.team && 
      player.status === 'Active' &&
      player.depth_chart_order && player.depth_chart_order <= 3) {
    return { should: true, reason: 'fantasy_relevant', priority: 10 }
  }
  
  if (player.metadata?.rookie_year === '2024' && player.position && ['QB', 'RB', 'WR', 'TE'].includes(player.position)) {
    return { should: true, reason: 'rookie_potential', priority: 7 }
  }
  
  if (player.position === 'K' && player.depth_chart_order === 1) {
    return { should: true, reason: 'starting_kicker', priority: 5 }
  }
  
  return { should: false, reason: 'not_fantasy_relevant', priority: 0 }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { limit = 50, test_mode = true, gemini_api_key } = await req.json().catch(() => ({}))

    // Return streaming response with real-time updates
    const stream = new ReadableStream({
      async start(controller) {
        try {
          sendProgressUpdate(controller, {
            step: "initialize",
            message: "🚀 Starting streaming data ingestion...",
            timestamp: new Date().toISOString()
          })

          const supabaseUrl = Deno.env.get('SUPABASE_URL')!
          const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
          const supabase = createClient(supabaseUrl, supabaseKey)

          // Step 1: Fetch player data
          sendProgressUpdate(controller, {
            step: "fetch_players",
            message: "📥 Fetching player data from Sleeper API...",
            timestamp: new Date().toISOString()
          })

          const sleeperResponse = await fetch('https://api.sleeper.app/v1/players/nfl')
          const playersData = await sleeperResponse.json()
          const totalPlayers = Object.keys(playersData).length

          sendProgressUpdate(controller, {
            step: "fetch_complete",
            message: `✅ Fetched ${totalPlayers} players from Sleeper API`,
            data: { totalPlayers },
            timestamp: new Date().toISOString()
          })

          // Step 2: Filter and prepare data
          sendProgressUpdate(controller, {
            step: "filter_players",
            message: "🔍 Filtering active fantasy players...",
            timestamp: new Date().toISOString()
          })

          const activePlayerIds = Object.keys(playersData).filter(id => {
            const player = playersData[id]
            return player.position && 
                   player.team &&  
                   player.position !== 'DEF' && 
                   ['QB', 'RB', 'WR', 'TE', 'K'].includes(player.position) && 
                   (player.status === 'Active' || !player.status)
          })

          const playerIdsToProcess = test_mode 
            ? activePlayerIds.slice(0, Math.min(limit, activePlayerIds.length))
            : activePlayerIds

          sendProgressUpdate(controller, {
            step: "filter_complete",
            message: `🎯 Selected ${playerIdsToProcess.length} players for processing`,
            data: { 
              totalActive: activePlayerIds.length,
              toProcess: playerIdsToProcess.length,
              testMode: test_mode
            },
            timestamp: new Date().toISOString()
          })

          // Step 3: Bulk sync raw data
          sendProgressUpdate(controller, {
            step: "sync_start",
            message: "💾 Starting bulk player sync to database...",
            timestamp: new Date().toISOString()
          })

          const playerInserts = Object.entries(playersData).map(([playerId, player]) => ({
            player_id: playerId,
            full_name: player.full_name,
            first_name: player.first_name,
            last_name: player.last_name,
            position: player.position,
            team: player.team,
            team_abbr: player.team_abbr,
            status: player.status,
            active: player.active,
            depth_chart_position: player.depth_chart_position,
            depth_chart_order: player.depth_chart_order,
            injury_status: player.injury_status,
            injury_notes: player.injury_notes,
            practice_participation: player.practice_participation,
            age: player.age,
            college: player.college,
            years_exp: player.years_exp,
            rookie_year: player.metadata?.rookie_year,
            raw_data: player
          }))

          // Batch sync with progress updates
          const batchSize = 1000
          let syncedCount = 0
          const totalBatches = Math.ceil(playerInserts.length / batchSize)

          for (let i = 0; i < playerInserts.length; i += batchSize) {
            const batch = playerInserts.slice(i, i + batchSize)
            const batchNum = Math.floor(i / batchSize) + 1
            
            sendProgressUpdate(controller, {
              step: "sync_batch",
              message: `⏳ Syncing batch ${batchNum}/${totalBatches} (${batch.length} players)...`,
              data: { 
                batchNum, 
                totalBatches, 
                batchSize: batch.length,
                synced: syncedCount,
                total: playerInserts.length,
                progress: Math.round((syncedCount / playerInserts.length) * 100)
              },
              timestamp: new Date().toISOString()
            })

            const { error } = await supabase
              .from('players_raw')
              .upsert(batch, { onConflict: 'player_id' })

            if (error) {
              sendProgressUpdate(controller, {
                step: "sync_error",
                message: `❌ Error in batch ${batchNum}: ${error.message}`,
                data: { batchNum, error: error.message },
                timestamp: new Date().toISOString()
              })
            } else {
              syncedCount += batch.length
              sendProgressUpdate(controller, {
                step: "sync_batch_complete",
                message: `✅ Batch ${batchNum}/${totalBatches} complete`,
                data: { 
                  batchNum,
                  totalBatches,
                  synced: syncedCount,
                  total: playerInserts.length,
                  progress: Math.round((syncedCount / playerInserts.length) * 100)
                },
                timestamp: new Date().toISOString()
              })
            }

            // Brief pause between batches
            await new Promise(resolve => setTimeout(resolve, 50))
          }

          // Step 4: Generate selective embeddings (if API key provided)
          if (gemini_api_key) {
            sendProgressUpdate(controller, {
              step: "embedding_start",
              message: "🧠 Starting selective embedding generation...",
              timestamp: new Date().toISOString()
            })

            // Find players that need embeddings
            const playersToEmbed = playerIdsToProcess
              .map(playerId => {
                const player = playersData[playerId]
                const embedInfo = shouldEmbed(player)
                return embedInfo.should ? {
                  playerId,
                  player,
                  reason: embedInfo.reason,
                  priority: embedInfo.priority
                } : null
              })
              .filter(Boolean)
              .sort((a, b) => b!.priority - a!.priority)

            sendProgressUpdate(controller, {
              step: "embedding_selected",
              message: `🎯 Selected ${playersToEmbed.length} players for embedding`,
              data: { 
                toEmbed: playersToEmbed.length,
                estimatedCost: (playersToEmbed.length * 0.0001).toFixed(4)
              },
              timestamp: new Date().toISOString()
            })

            // Generate embeddings in batches
            const embedBatchSize = 3 // Small batches for API limits
            let embeddedCount = 0

            for (let i = 0; i < playersToEmbed.length; i += embedBatchSize) {
              const batch = playersToEmbed.slice(i, i + embedBatchSize)
              const embedBatchNum = Math.floor(i / embedBatchSize) + 1
              const totalEmbedBatches = Math.ceil(playersToEmbed.length / embedBatchSize)

              sendProgressUpdate(controller, {
                step: "embedding_batch",
                message: `⚡ Embedding batch ${embedBatchNum}/${totalEmbedBatches}`,
                data: { 
                  players: batch.map(b => b!.player.full_name),
                  batchNum: embedBatchNum,
                  totalBatches: totalEmbedBatches,
                  embedded: embeddedCount,
                  total: playersToEmbed.length
                },
                timestamp: new Date().toISOString()
              })

              const batchResults = []
              for (const item of batch) {
                try {
                  const { playerId, player, reason, priority } = item!
                  const content = formatPlayerChunk(player, playerId)
                  const embedding = await generateEmbedding(content, gemini_api_key)

                  batchResults.push({
                    player_id: playerId,
                    content,
                    embedding: `[${embedding.join(',')}]`,
                    embed_reason: reason,
                    embed_priority: priority
                  })

                  sendProgressUpdate(controller, {
                    step: "embedding_player_complete",
                    message: `✨ Embedded: ${player.full_name}`,
                    data: { playerName: player.full_name, reason },
                    timestamp: new Date().toISOString()
                  })

                } catch (error) {
                  sendProgressUpdate(controller, {
                    step: "embedding_error",
                    message: `❌ Error embedding ${item?.player.full_name}: ${(error as Error).message}`,
                    timestamp: new Date().toISOString()
                  })
                }
              }

              // Save batch to database
              if (batchResults.length > 0) {
                const { error } = await supabase
                  .from('player_embeddings_selective')
                  .upsert(batchResults, { onConflict: 'player_id' })

                if (error) {
                  sendProgressUpdate(controller, {
                    step: "embedding_save_error",
                    message: `❌ Error saving embeddings: ${error.message}`,
                    timestamp: new Date().toISOString()
                  })
                } else {
                  embeddedCount += batchResults.length
                  sendProgressUpdate(controller, {
                    step: "embedding_batch_complete",
                    message: `✅ Batch ${embedBatchNum}/${totalEmbedBatches} saved`,
                    data: { 
                      embedded: embeddedCount,
                      total: playersToEmbed.length,
                      progress: Math.round((embeddedCount / playersToEmbed.length) * 100)
                    },
                    timestamp: new Date().toISOString()
                  })
                }
              }

              // API rate limiting pause
              if (i + embedBatchSize < playersToEmbed.length) {
                sendProgressUpdate(controller, {
                  step: "embedding_pause",
                  message: "⏸️ Pausing for API rate limits...",
                  timestamp: new Date().toISOString()
                })
                await new Promise(resolve => setTimeout(resolve, 2000))
              }
            }

            sendProgressUpdate(controller, {
              step: "complete",
              message: "🎉 Data ingestion completed successfully!",
              data: {
                totalPlayers: syncedCount,
                embeddedPlayers: embeddedCount,
                finalCost: (embeddedCount * 0.0001).toFixed(4)
              },
              timestamp: new Date().toISOString()
            })

          } else {
            sendProgressUpdate(controller, {
              step: "complete_no_embeddings", 
              message: "✅ Player sync completed. No embeddings generated (no API key).",
              data: { totalPlayers: syncedCount },
              timestamp: new Date().toISOString()
            })
          }

          controller.close()

        } catch (error) {
          sendProgressUpdate(controller, {
            step: "error",
            message: `❌ Fatal error: ${(error as Error).message}`,
            timestamp: new Date().toISOString()
          })
          controller.close()
        }
      }
    })

    return new Response(stream, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive'
      }
    })

  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: (error as Error).message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})