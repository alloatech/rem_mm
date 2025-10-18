// Setup type definitions for built-in Supabase Runtime APIs
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

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log("Starting daily player data ingestion...")

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Fetch player data from Sleeper API
    console.log("Fetching player data from Sleeper API...")
    const sleeperResponse = await fetch('https://api.sleeper.app/v1/players/nfl')
    
    if (!sleeperResponse.ok) {
      throw new Error(`Sleeper API error: ${sleeperResponse.status}`)
    }
    
    const playersData = await sleeperResponse.json() as Record<string, SleeperPlayer>
    console.log(`Fetched ${Object.keys(playersData).length} players from Sleeper API`)

    // TODO: Process player data and generate embeddings
    // 1. Format each player into semantic chunks
    // 2. Generate embeddings using Gemini Embedding API
    // 3. Upsert into player_embeddings table

    // For now, just process a few sample players to test the structure
    const samplePlayerIds = Object.keys(playersData).slice(0, 5)
    const processedPlayers = []

    for (const playerId of samplePlayerIds) {
      const player = playersData[playerId]
      const playerName = player.full_name || `${player.first_name || ''} ${player.last_name || ''}`.trim()
      
      // Create semantic chunk for this player
      const content = `Player: ${playerName}, Position: ${player.position || 'Unknown'}, Team: ${player.team || 'FA'}, Status: ${player.status || 'Unknown'}`
      
      processedPlayers.push({
        player_id: playerId,
        player_name: playerName,
        position: player.position,
        team: player.team,
        status: player.status,
        content: content,
        // TODO: Add actual embedding once Gemini integration is set up
        // embedding: await generateEmbedding(content),
        metadata: {
          last_updated: new Date().toISOString(),
          source: 'sleeper_api'
        }
      })
    }

    console.log(`Processed ${processedPlayers.length} sample players`)

    const response = {
      success: true,
      message: `Daily data ingestion completed successfully`,
      stats: {
        total_players_fetched: Object.keys(playersData).length,
        sample_players_processed: processedPlayers.length,
        timestamp: new Date().toISOString()
      },
      sample_players: processedPlayers
    }

    return new Response(
      JSON.stringify(response),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Error in daily-data-ingestion function:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error.message 
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

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/daily-data-ingestion' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
