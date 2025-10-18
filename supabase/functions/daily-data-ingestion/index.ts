// Complete RAG Data Ingestion Pipeline
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

console.log("daily-data-ingestion function loaded")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SleeperPlayer {
  player_id: string
  full_name?: string
  first_name?: string
  last_name?: string
  position?: string
  team?: string
  status?: string
  [key: string]: any
}

// Generate embedding using Gemini API
async function generateEmbedding(text: string, apiKey?: string): Promise<number[]> {
  const geminiApiKey = apiKey || Deno.env.get('GEMINI_API_KEY')
  if (!geminiApiKey) {
    throw new Error('GEMINI_API_KEY not found in environment or request')
  }

  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${geminiApiKey}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: "models/text-embedding-004",
        content: {
          parts: [{ text }]
        }
      })
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Gemini API error: ${response.status} - ${errorText}`)
    }

    const data = await response.json()
    return data.embedding?.values || []
  } catch (error) {
    console.error('Error generating embedding:', error)
    throw error
  }
}

// Format player data into semantic chunk
function formatPlayerChunk(player: SleeperPlayer, playerId: string): string {
  const playerName = player.full_name || `${player.first_name || ''} ${player.last_name || ''}`.trim()
  const position = player.position || 'Unknown'
  const team = player.team || 'FA'  // Free Agent if no team
  const status = player.status || 'Active'
  
  // Enhanced formatting for better search context
  return `Player: ${playerName}, Position: ${position}, Team: ${team}, Status: ${status}. Fantasy football player for the ${team} team playing ${position}.`
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log("🚀 Starting complete RAG data ingestion pipeline...")

    // Initialize Supabase client with service role key for database writes
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Check request parameters
    const { limit = 50, test_mode = true, gemini_api_key } = await req.json().catch(() => ({}))
    
    console.log(`📊 Processing mode: ${test_mode ? 'TEST' : 'FULL'} (limit: ${limit})`)

    // Validate API key is available
    if (!gemini_api_key) {
      throw new Error('gemini_api_key is required in request body for local development')
    }

    // Fetch player data from Sleeper API
    console.log("📥 Fetching player data from Sleeper API...")
    const sleeperResponse = await fetch('https://api.sleeper.app/v1/players/nfl')
    
    if (!sleeperResponse.ok) {
      throw new Error(`Sleeper API error: ${sleeperResponse.status}`)
    }
    
    const playersData = await sleeperResponse.json() as Record<string, SleeperPlayer>
    const totalPlayers = Object.keys(playersData).length
    console.log(`✅ Fetched ${totalPlayers} players from Sleeper API`)

    // Filter for active players with positions AND teams (fantasy relevant players)
    const activePlayerIds = Object.keys(playersData).filter(id => {
      const player = playersData[id]
      return player.position && 
             player.team &&  // Must have a team
             player.position !== 'DEF' && 
             ['QB', 'RB', 'WR', 'TE', 'K'].includes(player.position) && // Fantasy relevant positions
             (player.status === 'Active' || !player.status)
    })

    // Limit processing for test mode or parameter
    const playerIdsToProcess = test_mode 
      ? activePlayerIds.slice(0, Math.min(limit, activePlayerIds.length))
      : activePlayerIds // Process ALL players when not in test mode

    console.log(`🎯 Processing ${playerIdsToProcess.length} out of ${activePlayerIds.length} active players (test_mode: ${test_mode})...`)

    const processedPlayers = []
    const errors = []

    // Process players in batches to avoid rate limits
    const batchSize = 10
    for (let i = 0; i < playerIdsToProcess.length; i += batchSize) {
      const batch = playerIdsToProcess.slice(i, i + batchSize)
      console.log(`🔄 Processing batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(playerIdsToProcess.length/batchSize)}...`)

      const batchPromises = batch.map(async (playerId) => {
        try {
          const player = playersData[playerId]
          const playerName = player.full_name || `${player.first_name || ''} ${player.last_name || ''}`.trim()
          
          // Skip players without names
          if (!playerName || playerName.length < 2) {
            return null
          }

          // Create semantic chunk
          const content = formatPlayerChunk(player, playerId)
          
          // Generate embedding
          console.log(`🧠 Generating embedding for: ${playerName}`)
          const embedding = await generateEmbedding(content, gemini_api_key)
          
          if (!embedding || embedding.length === 0) {
            throw new Error('Empty embedding generated')
          }

          return {
            player_id: playerId,
            player_name: playerName,
            position: player.position,
            team: player.team,
            status: player.status || 'Active',
            content: content,
            embedding: `[${embedding.join(',')}]`, // PostgreSQL vector format
            metadata: {
              last_updated: new Date().toISOString(),
              source: 'sleeper_api',
              embedding_model: 'text-embedding-004',
              embedding_dimensions: embedding.length
            }
          }
        } catch (error) {
          const playerName = playersData[playerId]?.full_name || playerId
          console.error(`❌ Error processing ${playerName}:`, error.message)
          errors.push({ player_id: playerId, error: error.message })
          return null
        }
      })

      const batchResults = await Promise.all(batchPromises)
      const validResults = batchResults.filter(result => result !== null)
      processedPlayers.push(...validResults)

      // Small delay between batches to be respectful to Gemini API
      if (i + batchSize < playerIdsToProcess.length) {
        await new Promise(resolve => setTimeout(resolve, 1000))
      }
    }

    console.log(`✅ Generated embeddings for ${processedPlayers.length} players`)

    // Upsert into database
    if (processedPlayers.length > 0) {
      console.log("💾 Storing embeddings in database...")
      
      const { data, error } = await supabase
        .from('player_embeddings')
        .upsert(processedPlayers, { 
          onConflict: 'player_id',
          ignoreDuplicates: false 
        })

      if (error) {
        console.error('Database upsert error:', error)
        throw new Error(`Database error: ${error.message}`)
      }

      console.log(`✅ Successfully stored ${processedPlayers.length} player embeddings`)
    }

    const response = {
      success: true,
      message: `RAG data ingestion completed successfully`,
      stats: {
        total_players_fetched: totalPlayers,
        active_players_available: activePlayerIds.length,
        players_processed: processedPlayers.length,
        errors_encountered: errors.length,
        embeddings_stored: processedPlayers.length,
        test_mode: test_mode,
        timestamp: new Date().toISOString()
      },
      errors: errors.length > 0 ? errors : undefined,
      sample_players: processedPlayers.slice(0, 3).map(p => ({
        player_name: p.player_name,
        position: p.position,
        team: p.team,
        content: p.content,
        embedding_dimensions: p.metadata.embedding_dimensions
      }))
    }

    return new Response(
      JSON.stringify(response),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('❌ Fatal error in daily-data-ingestion:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false,
        error: 'Internal server error',
        message: error.message,
        timestamp: new Date().toISOString()
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  # Test mode (process 10 players)
  curl -i --location --request POST 'http://192.168.50.242:54321/functions/v1/daily-data-ingestion' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"test_mode": true, "limit": 10}'

  # Full mode (process more players)
  curl -i --location --request POST 'http://192.168.50.242:54321/functions/v1/daily-data-ingestion' \
    --header 'Authorization: Bearer ...' \
    --header 'Content-Type: application/json' \
    --data '{"test_mode": false, "limit": 100}'

*/
