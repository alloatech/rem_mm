// Optimized RAG Data Ingestion - Full Data + Selective Embeddings
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

console.log("optimized-data-ingestion function loaded")

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
  team_abbr?: string
  status?: string
  active?: boolean
  depth_chart_position?: string
  depth_chart_order?: number
  injury_status?: string
  injury_notes?: string
  injury_body_part?: string
  injury_start_date?: string
  practice_participation?: string
  practice_description?: string
  age?: number
  height?: string
  weight?: string
  college?: string
  years_exp?: number
  number?: number
  news_updated?: number
  rookie_year?: string
  espn_id?: string
  yahoo_id?: string
  fantasy_data_id?: number
  [key: string]: any
}

// Generate embedding using Gemini API (only for selective players)
async function generateEmbedding(text: string, apiKey?: string): Promise<number[]> {
  const geminiApiKey = apiKey || Deno.env.get('GEMINI_API_KEY')
  if (!geminiApiKey) {
    throw new Error('GEMINI_API_KEY not found')
  }

  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${geminiApiKey}`, {
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
  } catch (error) {
    console.error('Error generating embedding:', error)
    throw error
  }
}

// STABLE identity chunk - excludes frequently changing data  
function formatPlayerChunk(player: SleeperPlayer, playerId: string): string {
  const playerName = player.full_name || `${player.first_name || ''} ${player.last_name || ''}`.trim()
  const position = player.position || 'Unknown'
  const team = player.team || 'FA'
  
  // Build STABLE identity context (no injury/depth chart - those change frequently)
  let context = `Player: ${playerName}, Position: ${position}, Team: ${team}`
  
  // Add stable biographical data
  if (player.college) {
    context += `, College: ${player.college}`
  }
  
  if (player.years_exp !== undefined) {
    context += `, Experience: ${player.years_exp} years`
  }
  
  if (player.age) {
    context += `, Age: ${player.age}`
  }
  
  // Add rookie status for context
  if (player.metadata?.rookie_year === '2024') {
    context += `, Rookie Year: 2024`
  }
  
  // Physical attributes for position context
  if (player.height && player.weight) {
    context += `, Size: ${player.height}"/${player.weight}lbs`
  }
  
  context += `. Fantasy football ${position} for the ${team} team.`
  
  return context
}

// Determine if player should get expensive embedding (STABLE IDENTITY ONLY)
function shouldEmbed(player: SleeperPlayer): { should: boolean, reason: string, priority: number } {
  // Only embed STABLE player identity - not changing injury/depth chart data
  
  // High priority - Fantasy relevant starters (ignore injury status for embedding decision)
  if (player.position && ['QB', 'RB', 'WR', 'TE'].includes(player.position) && 
      player.team && 
      player.status === 'Active' &&
      player.depth_chart_order && player.depth_chart_order <= 3) { // Include backups for trades/injuries
    return { should: true, reason: 'fantasy_relevant', priority: 10 }
  }
  
  // Medium priority - All rookies (potential breakouts)
  if (player.metadata?.rookie_year === '2024' && player.position && ['QB', 'RB', 'WR', 'TE'].includes(player.position)) {
    return { should: true, reason: 'rookie_potential', priority: 7 }
  }
  
  // Kickers - only starters
  if (player.position === 'K' && player.depth_chart_order === 1) {
    return { should: true, reason: 'starting_kicker', priority: 5 }
  }
  
  // Key backups who get meaningful snaps
  if (player.position && ['QB', 'RB', 'WR', 'TE'].includes(player.position) && 
      player.team && 
      player.depth_chart_order && player.depth_chart_order <= 2 &&
      player.years_exp && player.years_exp >= 2) { // Experienced backups
    return { should: true, reason: 'key_backup', priority: 6 }
  }
  
  return { should: false, reason: 'not_fantasy_relevant', priority: 0 }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log("🚀 Starting optimized RAG data ingestion...")

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { force_embedding = false, gemini_api_key } = await req.json().catch(() => ({}))

    // STEP 1: Fetch ALL players from Sleeper (11,400+ players)
    console.log("📥 Fetching ALL player data from Sleeper API...")
    const sleeperResponse = await fetch('https://api.sleeper.app/v1/players/nfl')
    
    if (!sleeperResponse.ok) {
      throw new Error(`Sleeper API error: ${sleeperResponse.status}`)
    }
    
    const playersData = await sleeperResponse.json() as Record<string, SleeperPlayer>
    const totalPlayers = Object.keys(playersData).length
    console.log(`✅ Fetched ${totalPlayers} total players from Sleeper API`)

    // STEP 2: Bulk insert/update ALL players to raw table
    console.log("💾 Bulk syncing ALL players to database...")
    
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
      injury_body_part: player.injury_body_part,
      injury_start_date: player.injury_start_date,
      practice_participation: player.practice_participation,
      practice_description: player.practice_description,
      age: player.age,
      height: player.height,
      weight: player.weight,
      college: player.college,
      years_exp: player.years_exp,
      number: player.number,
      rookie_year: player.metadata?.rookie_year,
      espn_id: player.espn_id,
      yahoo_id: player.yahoo_id,
      fantasy_data_id: player.fantasy_data_id,
      news_updated: player.news_updated,
      raw_data: player // Store full JSON for future use
    }))

    // Batch insert in chunks of 1000 with detailed progress
    const batchSize = 1000
    let syncedCount = 0
    const totalBatches = Math.ceil(playerInserts.length / batchSize)
    
    console.log(`📊 Starting batch sync: ${totalBatches} batches of ~${batchSize} players each`)
    
    for (let i = 0; i < playerInserts.length; i += batchSize) {
      const batch = playerInserts.slice(i, i + batchSize)
      const batchNum = Math.floor(i / batchSize) + 1
      
      console.log(`⏳ Processing batch ${batchNum}/${totalBatches} (${batch.length} players)...`)
      
      const { error } = await supabase
        .from('players_raw')
        .upsert(batch, { 
          onConflict: 'player_id',
          ignoreDuplicates: false 
        })
      
      if (error) {
        console.error(`❌ Error syncing batch ${batchNum}/${totalBatches}:`, error)
      } else {
        syncedCount += batch.length
        const progressPercent = Math.round((syncedCount / totalPlayers) * 100)
        console.log(`✅ Batch ${batchNum}/${totalBatches} complete | Total: ${syncedCount}/${totalPlayers} (${progressPercent}%)`)
      }
      
      // Small delay between batches to avoid overwhelming database
      if (i + batchSize < playerInserts.length) {
        await new Promise(resolve => setTimeout(resolve, 100))
      }
    }

    console.log(`🎉 Successfully synced ${syncedCount} players to raw database`)

    // STEP 3: SELECTIVE embedding generation (only high-priority players)
    if (!gemini_api_key && !force_embedding) {
      return new Response(JSON.stringify({
        success: true,
        message: "Player data sync completed. No embedding generation (no API key provided).",
        stats: {
          total_players: totalPlayers,
          synced_players: syncedCount,
          embedded_players: 0
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log("🧠 Starting selective embedding generation...")
    
    // Get players that should be embedded
    const playersToEmbed = Object.entries(playersData)
      .map(([playerId, player]) => {
        const embedInfo = shouldEmbed(player)
        return embedInfo.should ? {
          playerId,
          player,
          reason: embedInfo.reason,
          priority: embedInfo.priority
        } : null
      })
      .filter(Boolean)
      .sort((a, b) => b!.priority - a!.priority) // Sort by priority

    console.log(`🎯 Selected ${playersToEmbed.length} high-priority players for embedding`)

    // Generate embeddings in batches with detailed progress
    const embedBatchSize = 5 // Smaller batches for API rate limiting
    let embeddedCount = 0
    const embedErrors: any[] = []
    const totalEmbedBatches = Math.ceil(playersToEmbed.length / embedBatchSize)

    console.log(`🧠 Starting embedding generation: ${totalEmbedBatches} batches of ~${embedBatchSize} players each`)
    console.log(`💰 Estimated cost: ~$${(playersToEmbed.length * 0.0001).toFixed(4)} for ${playersToEmbed.length} embeddings`)

    for (let i = 0; i < playersToEmbed.length; i += embedBatchSize) {
      const batch = playersToEmbed.slice(i, i + embedBatchSize)
      const embedBatchNum = Math.floor(i / embedBatchSize) + 1
      
      console.log(`⚡ Embedding batch ${embedBatchNum}/${totalEmbedBatches}: ${batch.map(b => b!.player.full_name).join(', ')}`)
      
      const batchPromises = batch.map(async (item) => {
        try {
          const { playerId, player, reason, priority } = item!
          const playerName = player.full_name || `${player.first_name || ''} ${player.last_name || ''}`.trim()
          
          console.log(`🧠 Embedding: ${playerName} (${reason}, priority: ${priority})`)
          
          const content = formatPlayerChunk(player, playerId)
          const embedding = await generateEmbedding(content, gemini_api_key)
          
          if (!embedding || embedding.length === 0) {
            throw new Error('Empty embedding generated')
          }

          return {
            player_id: playerId,
            content: content,
            embedding: `[${embedding.join(',')}]`,
            embed_reason: reason,
            embed_priority: priority
          }
        } catch (error) {
          const playerName = item?.player.full_name || item?.playerId
          console.error(`❌ Error embedding ${playerName}:`, error.message)
          embedErrors.push({ player_id: item?.playerId, error: error.message })
          return null
        }
      })

      const batchResults = await Promise.all(batchPromises)
      const validResults = batchResults.filter(result => result !== null)
      
      if (validResults.length > 0) {
        const { error } = await supabase
          .from('player_embeddings_selective')
          .upsert(validResults, { onConflict: 'player_id' })
        
        if (error) {
          console.error(`❌ Error inserting embedding batch ${embedBatchNum}:`, error)
        } else {
          embeddedCount += validResults.length
          const embedProgressPercent = Math.round((embeddedCount / playersToEmbed.length) * 100)
          console.log(`✅ Batch ${embedBatchNum}/${totalEmbedBatches} embedded | Total: ${embeddedCount}/${playersToEmbed.length} (${embedProgressPercent}%)`)
        }
      }

      // Rate limit pause between batches (respectful to Gemini API)
      if (i + embedBatchSize < playersToEmbed.length) {
        console.log(`⏸️  Pausing 2s between embedding batches (API rate limiting)...`)
        await new Promise(resolve => setTimeout(resolve, 2000))
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: "Optimized RAG data ingestion completed successfully!",
      stats: {
        total_players: totalPlayers,
        synced_players: syncedCount,
        embedded_players: embeddedCount,
        embedding_errors: embedErrors.length,
        priority_breakdown: playersToEmbed.reduce((acc, item) => {
          acc[item!.reason] = (acc[item!.reason] || 0) + 1
          return acc
        }, {} as Record<string, number>)
      },
      errors: embedErrors
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ Fatal error in optimized ingestion:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})