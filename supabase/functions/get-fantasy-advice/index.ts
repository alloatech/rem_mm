// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

// Type definitions
interface SimilarPlayer {
  player_id: string
  player_name: string
  pos: string
  team: string
  content: string
  similarity: number
}

declare const Deno: any

console.log("get-fantasy-advice function loaded")

// Security constants
const MAX_QUERY_LENGTH = 500

// Input validation and sanitization
function validateAndSanitizeInput(query: string): { isValid: boolean; sanitized: string; error?: string } {
  if (!query || typeof query !== 'string') {
    return { isValid: false, sanitized: '', error: 'Query must be a non-empty string' }
  }
  
  if (query.length > MAX_QUERY_LENGTH) {
    return { isValid: false, sanitized: '', error: `Query too long. Maximum ${MAX_QUERY_LENGTH} characters.` }
  }
  
  // Basic sanitization - remove potentially dangerous patterns
  const sanitized = query
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '') // Remove script tags
    .replace(/javascript:/gi, '') // Remove javascript: protocols
    .replace(/on\w+\s*=/gi, '') // Remove event handlers
    .trim()
  
  if (sanitized.length === 0) {
    return { isValid: false, sanitized: '', error: 'Query contains no valid content' }
  }
  
  return { isValid: true, sanitized }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGINS') || 'http://localhost:3000', // 🔒 Restrict origins
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
    // Get the request body
    const { query, context, gemini_api_key, sleeper_user_id, league_id } = await req.json()

    // Validate and sanitize input
    const validation = validateAndSanitizeInput(query)
    if (!validation.isValid) {
      return new Response(
        JSON.stringify({ error: validation.error }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Validate Sleeper integration inputs
    if (!sleeper_user_id || !league_id) {
      return new Response(
        JSON.stringify({ error: 'sleeper_user_id and league_id are required for roster-based advice' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 🏈 Sleeper Integration: Fetch user's roster
    console.log('🏈 Fetching roster for user:', sleeper_user_id, 'in league:', league_id)
    
    // Get league rosters
    const rostersResponse = await fetch(`https://api.sleeper.app/v1/league/${league_id}/rosters`)
    if (!rostersResponse.ok) {
      throw new Error(`Failed to fetch league rosters: ${rostersResponse.statusText}`)
    }
    
    const allRosters = await rostersResponse.json()
    const userRoster = allRosters.find((roster: any) => roster.owner_id === sleeper_user_id)
    
    if (!userRoster) {
      throw new Error('User not found in this league')
    }

    const userPlayerIds = userRoster.players || []
    console.log(`✅ Found ${userPlayerIds.length} players on user's roster`)

    // 🧠 RAG Pipeline Implementation
    console.log('🔍 Starting roster-aware RAG pipeline for query:', validation.sanitized)

    // Step 1: Generate embedding for user query using Gemini
    const geminiApiKey = gemini_api_key || Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      throw new Error('GEMINI_API_KEY not configured')
    }

    const embeddingResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${geminiApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'models/text-embedding-004',
          content: { parts: [{ text: validation.sanitized }] }
        })
      }
    )

    if (!embeddingResponse.ok) {
      throw new Error(`Gemini embedding failed: ${embeddingResponse.statusText}`)
    }

    const embeddingData = await embeddingResponse.json()
    const queryEmbedding = embeddingData.embedding.values
    console.log('✅ Generated query embedding, dimension:', queryEmbedding.length)

    // Step 2: Get user's rostered players from our database
    const { data: rosteredPlayers, error: rosterError } = await supabase
      .from('player_embeddings')
      .select('*')
      .in('player_id', userPlayerIds)

    if (rosterError) {
      console.error('Roster lookup error:', rosterError)
      throw new Error('Failed to lookup rostered players')
    }

    console.log(`🎯 Found ${rosteredPlayers?.length || 0} rostered players in our database`)

    // Step 3: Perform similarity search using pgvector on ALL players
    const { data: similarPlayers, error: searchError } = await supabase.rpc('search_similar_players', {
      query_embedding: queryEmbedding,
      similarity_threshold: 0.3,
      match_count: 10  // Get more to ensure we have options
    })

    if (searchError) {
      console.error('Similarity search error:', searchError)
      throw new Error('Failed to perform similarity search')
    }

    console.log(`🔍 Found ${similarPlayers?.length || 0} similar players`)

    // Step 4: Prioritize rostered players in the context
    const rosteredPlayerIds = new Set(userPlayerIds)
    const rosteredSimilarPlayers = similarPlayers?.filter((p: SimilarPlayer) => rosteredPlayerIds.has(p.player_id)) || []
    const otherSimilarPlayers = similarPlayers?.filter((p: SimilarPlayer) => !rosteredPlayerIds.has(p.player_id)) || []

    // Combine: rostered players first, then other similar players (for context)
    const prioritizedPlayers = [...rosteredSimilarPlayers, ...otherSimilarPlayers.slice(0, 3)]

    console.log(`🏆 Prioritized context: ${rosteredSimilarPlayers.length} rostered + ${otherSimilarPlayers.slice(0, 3).length} similar players`)

    // Step 5: Augment prompt with roster-aware context
    const playerContext = prioritizedPlayers?.length > 0 
      ? prioritizedPlayers.map((p: SimilarPlayer) => p.content).join('\n\n')
      : 'No specific player data found for this query.'

    const rosteredPlayersContext = rosteredSimilarPlayers?.length > 0
      ? `\n\nYOUR ROSTERED PLAYERS:\n${rosteredSimilarPlayers.map((p: SimilarPlayer) => p.content).join('\n')}`
      : '\n\nNo rostered players found matching this query.'

    const augmentedPrompt = `
You are an expert fantasy football analyst. Answer the following question using the provided NFL player data context, with special focus on the user's rostered players.

User Question: ${validation.sanitized}

Relevant Player Data:
${playerContext}
${rosteredPlayersContext}

Additional Context: ${context || 'None provided'}

IMPORTANT: When giving start/sit advice, prioritize players from "YOUR ROSTERED PLAYERS" section. If asking about positions like QB/RB/WR/TE, focus on the user's actual players at that position. Provide specific, actionable fantasy football advice based on the player data. Be concise but thorough.
`

    // Step 4: Generate response using Gemini Pro
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${geminiApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: augmentedPrompt }] }],
          generationConfig: {
            temperature: 0.7,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 1024
          }
        })
      }
    )

    if (!geminiResponse.ok) {
      throw new Error(`Gemini generation failed: ${geminiResponse.statusText}`)
    }

    const geminiData = await geminiResponse.json()
    const advice = geminiData.candidates[0].content.parts[0].text

    console.log('🎉 RAG pipeline completed successfully')

    const response = {
      query: validation.sanitized,
      advice: advice,
      roster_players_found: rosteredSimilarPlayers?.length || 0,
      similar_players_found: similarPlayers?.length || 0,
      sleeper_user_id: sleeper_user_id,
      league_id: league_id,
      context: context || "No additional context provided",
      timestamp: new Date().toISOString(),
      security_status: "✅ Request validated and processed"
    }

    return new Response(
      JSON.stringify(response),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Error in get-fantasy-advice function:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        request_id: crypto.randomUUID() // For debugging
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

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/get-fantasy-advice' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
