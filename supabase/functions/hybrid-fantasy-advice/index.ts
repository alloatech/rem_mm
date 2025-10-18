// Hybrid Fantasy Advice - Stable Embeddings + Real-time Filters
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { getCurrentUser, corsHeaders, logSecurityEvent } from '../_shared/auth.ts'

console.log("hybrid-fantasy-advice function loaded")

// Generate embedding using Gemini API
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

// Hybrid approach: Stable embeddings + Real-time filters
async function getHybridFantasyContext(
  query: string, 
  userPlayerId: string, 
  supabase: any, 
  geminiApiKey: string
): Promise<{
  relevantPlayers: any[]
  rosterContext: string
  realTimeContext: string[]
}> {
  console.log("🔍 Starting hybrid RAG: stable embeddings + real-time filters...")

  // Step 1: Generate query embedding
  const queryEmbedding = await generateEmbedding(query, geminiApiKey)
  console.log(`🧠 Generated query embedding: ${queryEmbedding.length} dimensions`)

  // Step 2: Get user's roster
  const { data: userRosterData } = await supabase
    .from('user_rosters')
    .select('player_id')
    .eq('sleeper_user_id', userPlayerId)

  const rosterPlayerIds = userRosterData?.map((r: any) => r.player_id) || []
  console.log(`👥 User roster: ${rosterPlayerIds.length} players`)

  // Step 3: Similarity search using STABLE embeddings
  const { data: similarPlayers, error } = await supabase.rpc('search_similar_players', {
    query_embedding: `[${queryEmbedding.join(',')}]`,
    similarity_threshold: 0.1,
    match_count: 15
  })

  if (error) {
    console.error('❌ Similarity search error:', error)
    throw new Error(`Similarity search failed: ${error.message}`)
  }

  // Step 4: Enrich with REAL-TIME data from players_raw
  const playerIds = similarPlayers?.map((p: any) => p.player_id) || []
  
  const { data: realTimeData, error: rtError } = await supabase
    .from('players_raw')
    .select(`
      player_id, full_name, position, team, status,
      injury_status, injury_notes, practice_participation,
      depth_chart_position, depth_chart_order, news_updated,
      age, college, years_exp
    `)
    .in('player_id', playerIds)

  if (rtError) {
    console.error('❌ Real-time data error:', rtError)
  }

  // Step 5: Combine stable identity + real-time status
  const enrichedPlayers = similarPlayers?.map((embedded: any) => {
    const realTime = realTimeData?.find((rt: any) => rt.player_id === embedded.player_id)
    const isRostered = rosterPlayerIds.includes(embedded.player_id)
    
    return {
      // Stable identity from embeddings
      player_id: embedded.player_id,
      player_name: embedded.player_name,
      position: embedded.pos,
      team: embedded.team,
      similarity: embedded.similarity,
      
      // Real-time context
      injury_status: realTime?.injury_status,
      injury_notes: realTime?.injury_notes,
      practice_status: realTime?.practice_participation,
      depth_chart_order: realTime?.depth_chart_order,
      depth_chart_position: realTime?.depth_chart_position,
      
      // Computed flags
      is_rostered: isRostered,
      is_starter: realTime?.depth_chart_order === 1,
      is_healthy: !realTime?.injury_status || ['Healthy', null].includes(realTime?.injury_status),
      
      // Metadata
      age: realTime?.age,
      college: realTime?.college,
      experience: realTime?.years_exp,
      last_updated: realTime?.news_updated
    }
  }).filter((player: any) => {
    // Apply real-time filters
    return player.team && player.team !== 'FA' // Active players only
  }) || []

  // Step 6: Generate real-time context strings
  const realTimeContext = []
  
  // Injury context
  const injuredPlayers = enrichedPlayers.filter(p => p.injury_status && p.injury_status !== 'Healthy')
  if (injuredPlayers.length > 0) {
    realTimeContext.push(`Injury updates: ${injuredPlayers.map(p => `${p.player_name} (${p.injury_status})`).join(', ')}`)
  }
  
  // Starter context
  const starters = enrichedPlayers.filter(p => p.is_starter && p.is_rostered)
  if (starters.length > 0) {
    realTimeContext.push(`Your starters: ${starters.map(p => `${p.player_name} (#1 ${p.position})`).join(', ')}`)
  }
  
  // Practice context
  const practiceIssues = enrichedPlayers.filter(p => p.practice_status && !['Full', 'FP'].includes(p.practice_status))
  if (practiceIssues.length > 0) {
    realTimeContext.push(`Practice concerns: ${practiceIssues.map(p => `${p.player_name} (${p.practice_status})`).join(', ')}`)
  }

  console.log(`🎯 Final context: ${enrichedPlayers.length} players with real-time data`)

  return {
    relevantPlayers: enrichedPlayers,
    rosterContext: rosterPlayerIds.length > 0 ? 
      `Your roster (${rosterPlayerIds.length} players): Focus on these players for start/sit decisions.` :
      'No roster data available',
    realTimeContext
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log("🚀 Starting hybrid fantasy advice generation...")

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get authentication first
    const authResult = await getCurrentUser(req, supabase)
    
    // 🔐 AUDIT: Function entry
    await logSecurityEvent(
      supabase,
      'fantasy_advice_enter',
      authResult.sleeper_user_id,
      { function: 'hybrid-fantasy-advice', auth_method: authResult.user ? 'jwt' : 'manual' },
      req
    )
    
    const { query, gemini_api_key, sleeper_user_id } = await req.json()

    // Validation
    if (!query || typeof query !== 'string') {
      throw new Error('Query is required')
    }

    if (!gemini_api_key) {
      throw new Error('Gemini API key is required')
    }

    // Determine user - prefer authenticated user, fallback to manual sleeper_user_id
    let finalSleeperUserId = authResult.sleeper_user_id || sleeper_user_id
    
    if (!finalSleeperUserId) {
      // No authenticated user and no manual ID - provide general advice
      console.log('⚠️ No user context - providing general fantasy advice')
    } else {
      console.log(`✅ User context: ${finalSleeperUserId} (${authResult.user ? 'authenticated' : 'manual'})`)
    }

    console.log(`📝 Query: "${query}"`)
    console.log(`👤 User: ${finalSleeperUserId || 'anonymous'}`)

    // 🔐 AUDIT: Query processing
    await logSecurityEvent(
      supabase,
      'fantasy_query_processing',
      finalSleeperUserId,
      { query_preview: query.substring(0, 100), has_user_context: !!finalSleeperUserId },
      req
    )

    // Get hybrid context (stable embeddings + real-time filters)
    const context = await getHybridFantasyContext(
      query,
      finalSleeperUserId,
      supabase,
      gemini_api_key
    )

    // Build enhanced prompt with both stable identity and real-time context
    const systemPrompt = `You are an expert fantasy football advisor. Use the provided player data and real-time context to give specific, actionable advice.

IMPORTANT INSTRUCTIONS:
- Prioritize players on the user's roster
- Consider injury status and practice participation  
- Factor in depth chart position (starters vs backups)
- Give specific start/sit recommendations
- Explain your reasoning with current context

Player Data (Stable Identity + Real-Time Status):
${JSON.stringify(context.relevantPlayers, null, 2)}

User Context:
${context.rosterContext}

Current Real-Time Updates:
${context.realTimeContext.join('\n')}

Please provide specific fantasy football advice based on this data.`

    // Generate advice using Gemini Pro
    const adviceResponse = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${gemini_api_key}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [{ 
            text: `${systemPrompt}\n\nUser Question: ${query}` 
          }]
        }],
        generationConfig: {
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1000
        }
      })
    })

    if (!adviceResponse.ok) {
      throw new Error(`Gemini advice generation failed: ${adviceResponse.status}`)
    }

    const adviceData = await adviceResponse.json()
    const advice = adviceData.candidates?.[0]?.content?.parts?.[0]?.text || "No advice generated"

    // 🔐 AUDIT: Successful completion
    await logSecurityEvent(
      supabase,
      'fantasy_advice_success',
      finalSleeperUserId,
      { 
        players_analyzed: context.relevantPlayers.length,
        advice_length: advice.length,
        rostered_players: context.relevantPlayers.filter((p: any) => p.is_rostered).length
      },
      req
    )

    return new Response(JSON.stringify({
      success: true,
      query,
      advice,
      authentication: {
        user_authenticated: !!authResult.user,
        sleeper_user_id: finalSleeperUserId,
        auth_method: authResult.user ? 'jwt_token' : 'manual_parameter'
      },
      context: {
        relevant_players_count: context.relevantPlayers.length,
        rostered_players: context.relevantPlayers.filter((p: any) => p.is_rostered).length,
        injured_players: context.relevantPlayers.filter((p: any) => p.injury_status && p.injury_status !== 'Healthy').length,
        starters: context.relevantPlayers.filter((p: any) => p.is_starter).length,
        real_time_updates: context.realTimeContext.length
      },
      metadata: {
        embedding_approach: "hybrid_stable_identity_plus_realtime_filters",
        cost_optimization: "embeddings_generated_once_per_season",
        data_freshness: "real_time_injury_depth_chart_practice_data"
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error: any) {
    console.error('❌ Error in hybrid fantasy advice:', error)
    
    // 🔐 AUDIT: Error occurred
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
      const supabase = createClient(supabaseUrl, supabaseKey)
      
      await logSecurityEvent(
        supabase,
        'fantasy_advice_error',
        null,
        { error: error?.message || 'Unknown error', function: 'hybrid-fantasy-advice' },
        req
      )
    } catch (auditError) {
      console.error('❌ Audit logging failed:', auditError)
    }
    
    return new Response(JSON.stringify({
      success: false,
      error: error?.message || 'An error occurred'
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})