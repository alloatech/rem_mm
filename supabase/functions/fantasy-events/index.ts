// Fantasy Football Event System using Supabase Realtime
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

console.log("fantasy-events function loaded")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Event types for fantasy football
interface FantasyEvent {
  type: 'injury_update' | 'depth_chart_change' | 'trade_alert' | 'waiver_pickup'
  player_id: string
  data: any
  timestamp: string
  user_impact?: string[]  // User IDs who should be notified
}

async function processFantasyEvent(event: FantasyEvent, supabase: any) {
  console.log(`📢 Processing event: ${event.type} for player ${event.player_id}`)
  
  switch (event.type) {
    case 'injury_update':
      await handleInjuryUpdate(event, supabase)
      break
    case 'depth_chart_change':
      await handleDepthChartChange(event, supabase)
      break
    case 'trade_alert':
      await handleTradeAlert(event, supabase)
      break
  }
}

async function handleInjuryUpdate(event: FantasyEvent, supabase: any) {
  const { player_id, data } = event
  
  // Find users who have this player
  const { data: affectedUsers } = await supabase
    .from('user_rosters')
    .select('sleeper_user_id, app_users!inner(username)')
    .eq('player_id', player_id)
  
  // Update player status
  await supabase
    .from('players_raw')
    .update({ injury_status: data.new_status })
    .eq('player_id', player_id)
  
  // Broadcast to affected users via Realtime
  const channel = supabase.channel('injury-alerts')
  for (const user of affectedUsers || []) {
    await channel.send({
      type: 'broadcast',
      event: 'injury_alert',
      payload: {
        player_id,
        player_name: data.player_name,
        injury_status: data.new_status,
        user_id: user.sleeper_user_id,
        message: `${data.player_name} injury update: ${data.new_status}`
      }
    })
  }
}

async function handleDepthChartChange(event: FantasyEvent, supabase: any) {
  // Update depth chart positions
  // Notify users about starter changes
  // Potentially regenerate embeddings if major role change
}

async function handleTradeAlert(event: FantasyEvent, supabase: any) {
  // Update team assignments
  // Refresh affected user rosters
  // Update player embeddings with new team context
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { action, event_data } = await req.json()

    switch (action) {
      case 'subscribe_to_events':
        // Return instructions for client-side event subscription
        return new Response(JSON.stringify({
          success: true,
          subscription_info: {
            channel: 'fantasy-events',
            events: ['injury_update', 'depth_chart_change', 'trade_alert'],
            example: {
              javascript: `
                supabase
                  .channel('fantasy-events')
                  .on('broadcast', { event: 'injury_alert' }, (payload) => {
                    console.log('Injury alert:', payload)
                  })
                  .subscribe()
              `
            }
          }
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

      case 'trigger_event':
        // Manually trigger an event (for testing or external webhooks)
        await processFantasyEvent(event_data, supabase)
        return new Response(JSON.stringify({
          success: true,
          message: `Event ${event_data.type} processed`,
          timestamp: new Date().toISOString()
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

      case 'get_user_events':
        // Get events for a specific user
        const { sleeper_user_id } = event_data
        
        // Find recent events affecting this user's players
        const { data: userPlayers } = await supabase
          .from('user_rosters')
          .select('player_id')
          .eq('sleeper_user_id', sleeper_user_id)

        const playerIds = userPlayers?.map(p => p.player_id) || []
        
        const { data: recentEvents } = await supabase
          .from('players_raw')
          .select('player_id, full_name, injury_status, depth_chart_order, last_synced')
          .in('player_id', playerIds)
          .not('injury_status', 'is', null)
          .order('last_synced', { ascending: false })
          .limit(10)

        return new Response(JSON.stringify({
          success: true,
          user_events: recentEvents,
          message: `Found ${recentEvents?.length || 0} recent events for user`
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

      default:
        throw new Error('Unknown action')
    }

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