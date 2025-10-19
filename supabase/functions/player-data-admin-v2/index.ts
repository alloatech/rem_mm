// Enhanced Player Data Admin with Supabase Storage Integration
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { logSecurityEvent, verifyAdminAccess } from '../_shared/auth.ts'

console.log("player-data-admin-v2 function loaded")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const STORAGE_BUCKET = 'player-data-backups'

interface BackupMetadata {
  filename: string
  size: number
  created_at: string
  record_count: number
  data_type: 'players' | 'embeddings'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    // Auth
    const authHeader = req.headers.get('Authorization')
    const jwt = authHeader?.replace('Bearer ', '')
    
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } }
    })
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    // Verify admin
    const adminCheck = await verifyAdminAccess(supabaseClient, supabase, jwt!)
    if (!adminCheck.isAdmin) {
      return new Response(
        JSON.stringify({ success: false, error: 'Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { action, data } = await req.json()
    console.log(`📊 Admin action: ${action}`)

    await logSecurityEvent(
      supabase,
      'admin_player_data_action_v2',
      adminCheck.sleeperUserId!,
      { action },
      req
    )

    switch (action) {
      case 'check_existing_data': {
        // Check if we already have data (avoid unnecessary API calls)
        const [playersCount, embeddingsCount, backups] = await Promise.all([
          supabase.from('players_raw').select('player_id', { count: 'exact', head: true }),
          supabase.from('player_embeddings_selective').select('id', { count: 'exact', head: true }),
          listStorageBackups(supabase, 'players')
        ])

        const hasPlayers = (playersCount.count || 0) > 0
        const hasEmbeddings = (embeddingsCount.count || 0) > 0
        const hasBackups = backups.length > 0

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              players: {
                count: playersCount.count || 0,
                exists: hasPlayers
              },
              embeddings: {
                count: embeddingsCount.count || 0,
                exists: hasEmbeddings
              },
              backups: {
                available: hasBackups,
                count: backups.length,
                latest: backups[0] || null,
                list: backups
              }
            },
            recommendation: getBootstrapRecommendation(
              hasPlayers,
              hasEmbeddings,
              hasBackups
            )
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'list_backups': {
        const { data_type = 'players' } = data || {}
        const backups = await listStorageBackups(supabase, data_type)

        return new Response(
          JSON.stringify({
            success: true,
            backups,
            count: backups.length
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'backup_to_storage': {
        // Export data and save to Supabase Storage
        const { data_type = 'players', description = '' } = data || {}
        
        console.log(`💾 Backing up ${data_type} to storage...`)
        
        let exportData: any
        let count = 0
        
        if (data_type === 'players') {
          const { data: players, error } = await supabase
            .from('players_raw')
            .select('*')
            .order('full_name')
          
          if (error) throw error
          exportData = players
          count = players?.length || 0
        } else {
          const { data: embeddings, error } = await supabase
            .from('player_embeddings_selective')
            .select('*')
            .order('embed_priority', { ascending: false })
          
          if (error) throw error
          exportData = embeddings
          count = embeddings?.length || 0
        }

        // Create backup object
        const backup = {
          data_type,
          count,
          exported_at: new Date().toISOString(),
          description,
          data: exportData
        }

        // Save to storage
        const filename = `${data_type}_${Date.now()}.json`
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from(STORAGE_BUCKET)
          .upload(filename, JSON.stringify(backup), {
            contentType: 'application/json',
            upsert: false
          })

        if (uploadError) throw uploadError

        // Save metadata
        await saveBackupMetadata(supabase, {
          filename,
          size: JSON.stringify(backup).length,
          created_at: new Date().toISOString(),
          record_count: count,
          data_type
        })

        return new Response(
          JSON.stringify({
            success: true,
            message: `Backed up ${count} ${data_type} records`,
            filename,
            size: JSON.stringify(backup).length,
            count
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'restore_from_storage': {
        // Restore data from Supabase Storage backup
        const { filename } = data || {}
        
        if (!filename) {
          throw new Error('filename required')
        }

        console.log(`📥 Restoring from storage: ${filename}`)

        // Download from storage
        const { data: fileData, error: downloadError } = await supabase.storage
          .from(STORAGE_BUCKET)
          .download(filename)

        if (downloadError) throw downloadError

        const backup = JSON.parse(await fileData.text())
        const dataToRestore = backup.data

        // Restore based on type
        let result
        if (backup.data_type === 'players') {
          result = await supabase
            .from('players_raw')
            .upsert(dataToRestore, { onConflict: 'player_id' })
        } else {
          // Remove id for embeddings
          const embeddingsToInsert = dataToRestore.map(({ id, ...rest }: any) => rest)
          result = await supabase
            .from('player_embeddings_selective')
            .upsert(embeddingsToInsert, { onConflict: 'player_id' })
        }

        if (result.error) throw result.error

        return new Response(
          JSON.stringify({
            success: true,
            message: `Restored ${backup.count} ${backup.data_type} records`,
            count: backup.count,
            data_type: backup.data_type,
            backup_date: backup.exported_at
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'smart_bootstrap': {
        // Intelligent bootstrap: check what exists and recommend best path
        const { force_fresh = false, gemini_api_key } = data || {}

        console.log('🚀 Starting smart bootstrap...')

        // Step 1: Check existing data
        const [playersCount, embeddingsCount, playerBackups, embeddingBackups] = await Promise.all([
          supabase.from('players_raw').select('player_id', { count: 'exact', head: true }),
          supabase.from('player_embeddings_selective').select('id', { count: 'exact', head: true }),
          listStorageBackups(supabase, 'players'),
          listStorageBackups(supabase, 'embeddings')
        ])

        const backups = [...playerBackups, ...embeddingBackups]
        const hasPlayers = (playersCount.count || 0) > 100 // At least some data
        const hasEmbeddings = (embeddingsCount.count || 0) > 50
        const hasPlayerBackup = playerBackups.length > 0
        const hasEmbeddingBackup = embeddingBackups.length > 0

        const plan = []
        let estimatedCost = 0
        let estimatedTime = 0

                // Decision tree
        if (!force_fresh && hasPlayerBackup && hasEmbeddingBackup) {
          // Best case: restore both from backup
          plan.push({
            step: 'restore_players',
            action: 'restore_from_storage',
            filename: playerBackups[0].filename,
            cost: 0,
            time: 3,
            reason: 'Player backup available in Storage'
          })

          plan.push({
            step: 'restore_embeddings',
            action: 'restore_from_storage',
            filename: embeddingBackups[0].filename,
            cost: 0,
            time: 2,
            reason: 'Embedding backup available in Storage'
          })
          estimatedTime += 5
        } else if (!force_fresh && hasPlayerBackup && !hasPlayers) {
          // Restore players from backup, create embeddings if needed
          plan.push({
            step: 'restore_players',
            action: 'restore_from_storage',
            filename: playerBackups[0].filename,
            cost: 0,
            time: 3,
            reason: 'Player backup available in Storage'
          })
          estimatedTime += 3

          if (hasEmbeddingBackup) {
            plan.push({
              step: 'restore_embeddings',
              action: 'restore_from_storage',
              filename: embeddingBackups[0].filename,
              cost: 0,
              time: 2,
              reason: 'Embedding backup available'
            })
            estimatedTime += 2
          } else if (gemini_api_key) {
            plan.push({
              step: 'create_embeddings',
              action: 'run_ingestion',
              cost: 0.50,
              time: 300,
              reason: 'No embedding backup, will create fresh'
            })
            estimatedCost += 0.50
            estimatedTime += 300
          }
        } else if (!hasPlayers || force_fresh) {
          // Need to fetch from Sleeper OR restore from backup
          const playerBackup = backups.find((b: any) => b.data_type === 'players')
          
          if (playerBackup && !force_fresh) {
            // Restore raw players from Storage backup (faster, no API call)
            plan.push({
              step: 'restore_players',
              action: 'restore_from_storage',
              filename: playerBackup.filename,
              cost: 0,
              time: 3,
              reason: 'Player backup available in Storage'
            })
            estimatedTime += 3
          } else {
            // Fetch fresh from Sleeper API
            plan.push({
              step: 'fetch_players',
              action: 'fetch_sleeper_data',
              cost: 0,
              time: 15,
              reason: force_fresh ? 'Forced fresh data' : 'No player backup available'
            })
            estimatedTime += 15

            // Backup raw players after fetching
            plan.push({
              step: 'backup_players',
              action: 'backup_to_storage',
              data_type: 'players',
              cost: 0,
              time: 3,
              reason: 'Save raw players for future use'
            })
            estimatedTime += 3
          }

          // Now handle embeddings
          const embeddingBackup = backups.find((b: any) => b.data_type === 'embeddings')
          
          if (embeddingBackup && !force_fresh) {
            // Restore embeddings from backup
            plan.push({
              step: 'restore_embeddings',
              action: 'restore_from_storage',
              filename: embeddingBackup.filename,
              cost: 0,
              time: 2,
              reason: 'Embedding backup available'
            })
            estimatedTime += 2
          } else if (gemini_api_key) {
            // Create fresh embeddings
            plan.push({
              step: 'create_embeddings',
              action: 'run_ingestion',
              cost: 0.50,
              time: 300,
              reason: force_fresh ? 'Forced fresh embeddings' : 'No embedding backup'
            })
            estimatedCost += 0.50
            estimatedTime += 300

            // Backup embeddings after creation
            plan.push({
              step: 'backup_embeddings',
              action: 'backup_to_storage',
              data_type: 'embeddings',
              cost: 0,
              time: 3,
              reason: 'Save embeddings for future use'
            })
            estimatedTime += 3
          }
        }

        return new Response(
          JSON.stringify({
            success: true,
            current_state: {
              players: playersCount.count || 0,
              embeddings: embeddingsCount.count || 0,
              backups_available: backups.length
            },
            plan,
            estimated_cost: estimatedCost,
            estimated_time_seconds: estimatedTime,
            recommendation: getBootstrapRecommendation(hasPlayers, hasEmbeddings, hasPlayerBackup || hasEmbeddingBackup)
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'execute_bootstrap_plan': {
        // Execute the smart bootstrap plan
        const { plan, gemini_api_key } = data || {}
        
        if (!plan || !Array.isArray(plan)) {
          throw new Error('plan array required')
        }

        const results = []

        for (const step of plan) {
          console.log(`▶️ Executing: ${step.step}`)
          
          try {
            let result
            
            switch (step.action) {
              case 'restore_from_storage':
                const restoreResp = await fetch(`${supabaseUrl}/functions/v1/player-data-admin-v2`, {
                  method: 'POST',
                  headers: {
                    'Authorization': `Bearer ${jwt}`,
                    'Content-Type': 'application/json'
                  },
                  body: JSON.stringify({
                    action: 'restore_from_storage',
                    data: { filename: step.filename }
                  })
                })
                result = await restoreResp.json()
                break

              case 'fetch_sleeper_data':
                const sleeperResp = await fetch('https://api.sleeper.app/v1/players/nfl')
                const playersData = await sleeperResp.json()
                const fantasyPlayers = transformSleeperData(playersData)
                await supabase.from('players_raw').upsert(fantasyPlayers, { onConflict: 'player_id' })
                result = { count: fantasyPlayers.length }
                break

              case 'run_ingestion':
                if (!gemini_api_key) {
                  results.push({
                    step: step.step,
                    skipped: true,
                    reason: 'No Gemini API key provided'
                  })
                  continue
                }
                
                const ingestionResp = await fetch(`${supabaseUrl}/functions/v1/simple-ingestion`, {
                  method: 'POST',
                  headers: {
                    'Authorization': `Bearer ${jwt}`,
                    'Content-Type': 'application/json'
                  },
                  body: JSON.stringify({
                    limit: 500,
                    test_mode: false,
                    gemini_api_key
                  })
                })
                result = await ingestionResp.json()
                break

              case 'backup_to_storage':
                const dataType = step.data_type || 'both'
                const typesToBackup = dataType === 'both' ? ['players', 'embeddings'] : [dataType]
                
                for (const type of typesToBackup) {
                  const backupResp = await fetch(`${supabaseUrl}/functions/v1/player-data-admin-v2`, {
                    method: 'POST',
                    headers: {
                      'Authorization': `Bearer ${jwt}`,
                      'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                      action: 'backup_to_storage',
                      data: { data_type: type }
                    })
                  })
                  await backupResp.json()
                }
                result = { backed_up: typesToBackup.length, types: typesToBackup }
                break
            }

            results.push({
              step: step.step,
              success: true,
              result
            })
          } catch (error: any) {
            results.push({
              step: step.step,
              success: false,
              error: error.message
            })
          }
        }

        return new Response(
          JSON.stringify({
            success: true,
            results,
            message: 'Bootstrap plan executed'
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'get_stats':
        // ... (keep existing stats code)
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

      default:
        return new Response(
          JSON.stringify({
            success: false,
            error: `Unknown action: ${action}`,
            availableActions: [
              'check_existing_data',
              'list_backups',
              'backup_to_storage',
              'restore_from_storage',
              'smart_bootstrap',
              'execute_bootstrap_plan',
              'get_stats'
            ]
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }

  } catch (error: any) {
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

// Helper functions
async function listStorageBackups(supabase: any, dataType?: string): Promise<BackupMetadata[]> {
  const { data: files, error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .list()

  if (error) {
    console.warn('Storage not initialized:', error)
    return []
  }

  const backups: BackupMetadata[] = []

  for (const file of files || []) {
    if (dataType && !file.name.startsWith(dataType)) continue

    // Get metadata
    const { data: metaData } = await supabase
      .from('backup_metadata')
      .select('*')
      .eq('filename', file.name)
      .single()

    backups.push(metaData || {
      filename: file.name,
      size: file.metadata?.size || 0,
      created_at: file.created_at,
      record_count: 0,
      data_type: file.name.startsWith('players') ? 'players' : 'embeddings'
    })
  }

  return backups.sort((a, b) => 
    new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  )
}

async function saveBackupMetadata(supabase: any, metadata: BackupMetadata) {
  await supabase.from('backup_metadata').upsert(metadata, { onConflict: 'filename' })
}

function getBootstrapRecommendation(
  hasPlayers: boolean,
  hasEmbeddings: boolean,
  hasBackups: boolean
): string {
  if (hasBackups) {
    return '✅ RECOMMENDED: Restore from backups (fastest, free, 2-3 seconds)'
  }
  if (hasPlayers && hasEmbeddings) {
    return '✅ Data already exists. Create backup for future use.'
  }
  if (hasPlayers && !hasEmbeddings) {
    return '⚠️ Players exist but no embeddings. Run ingestion ($0.50, 3-5 min) or restore from backup.'
  }
  return '🚀 Fresh start needed. Fetch from Sleeper (free, 15 sec) then run ingestion ($0.50, 3-5 min).'
}

function transformSleeperData(playersData: any): any[] {
  const fantasyPositions = ['QB', 'RB', 'WR', 'TE', 'K', 'DEF']
  
  return Object.entries(playersData)
    .map(([id, player]: [string, any]) => ({
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
      age: player.age,
      height: player.height,
      weight: player.weight,
      college: player.college,
      years_exp: player.years_exp,
      number: player.number,
      rookie_year: player.rookie_year,
      raw_data: player,
      news_updated: player.news_updated,
      last_synced: new Date().toISOString()
    }))
    .filter(p => p.position && fantasyPositions.includes(p.position) && p.active)
}

async function getPlayerStats(supabase: any) {
  const { data: players } = await supabase
    .from('players_raw')
    .select('position, team, status, active, injury_status, last_synced')

  const stats: any = {
    totalPlayers: players?.length || 0,
    byPosition: {},
    byTeam: {},
    byStatus: {},
    activeCount: 0,
    injuredCount: 0,
    lastSyncTime: null
  }

  players?.forEach((player: any) => {
    if (player.position) stats.byPosition[player.position] = (stats.byPosition[player.position] || 0) + 1
    if (player.team) stats.byTeam[player.team] = (stats.byTeam[player.team] || 0) + 1
    if (player.status) stats.byStatus[player.status] = (stats.byStatus[player.status] || 0) + 1
    if (player.active) stats.activeCount++
    if (player.injury_status) stats.injuredCount++
  })

  return stats
}

async function getEmbeddingStats(supabase: any) {
  const { data: embeddings } = await supabase
    .from('player_embeddings_selective')
    .select('embed_reason, embed_priority, content, embedding_created')

  const stats: any = {
    totalEmbedded: embeddings?.length || 0,
    byReason: {},
    byPriority: {},
    averageContentLength: 0,
    oldestEmbedding: null,
    newestEmbedding: null
  }

  let totalLength = 0
  embeddings?.forEach((emb: any) => {
    if (emb.embed_reason) stats.byReason[emb.embed_reason] = (stats.byReason[emb.embed_reason] || 0) + 1
    if (emb.content) totalLength += emb.content.length
  })

  stats.averageContentLength = embeddings?.length ? Math.round(totalLength / embeddings.length) : 0

  return stats
}
