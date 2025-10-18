// Admin Management - Role administration and user management
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { getCurrentUser, corsHeaders, logSecurityEvent } from '../_shared/auth.ts'

console.log("admin-management function loaded")

Deno.serve(async (req) => {
  console.log("🚀 Admin management function called")
  
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log("📝 Parsing request body...")
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Parse request body first
    const requestBody = await req.json()
    
    // Handle authentication - JWT or manual
    let authResult: { sleeper_user_id: string; user: any } | null = null
    const authHeader = req.headers.get('Authorization')
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      // Try JWT authentication
      try {
        const token = authHeader.replace('Bearer ', '')
        const { data: { user }, error } = await supabase.auth.getUser(token)
        
        if (error || !user) {
          console.log('JWT verification failed:', error)
        } else {
          // Get sleeper_user_id from app_users table
          const { data: appUser } = await supabase
            .from('app_users')
            .select('sleeper_user_id')
            .eq('supabase_user_id', user.id)
            .single()
          
          if (appUser) {
            authResult = { sleeper_user_id: appUser.sleeper_user_id, user }
          }
        }
      } catch (error) {
        console.log('JWT auth error:', error)
      }
    }
    
    // If no JWT auth, try manual auth from request body
    if (!authResult && requestBody.sleeper_user_id) {
      authResult = { sleeper_user_id: requestBody.sleeper_user_id, user: null }
    }
    
    if (!authResult || !authResult.sleeper_user_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Authentication required - provide JWT token or sleeper_user_id'
      }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Set current user context for RLS FIRST
    await supabase.rpc('set_config', {
      setting_name: 'app.current_sleeper_user_id',
      setting_value: authResult.sleeper_user_id,
      is_local: true
    })

    // 🔐 AUDIT: Admin function entry
    await logSecurityEvent(
      supabase,
      'admin_management_enter',
      authResult.sleeper_user_id,
      { function: 'admin-management', auth_method: authResult.user ? 'jwt' : 'manual' },
      req
    )

    const { action, target_user_id, new_role, reason } = requestBody

    if (action === 'check_admin_status') {
      // Check admin status by querying the user's role
      const { data: userRole, error: userError } = await supabase.rpc('get_user_role', {
        target_sleeper_user_id: authResult.sleeper_user_id
      })

      if (userError || !userRole) {
        return new Response(JSON.stringify({
          success: false,
          error: 'User not found'
        }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const isAdmin = userRole === 'admin' || userRole === 'super_admin'
      const isSuperAdmin = userRole === 'super_admin'

      await logSecurityEvent(
        supabase,
        'admin_status_check',
        authResult.sleeper_user_id,
        { is_admin: isAdmin, is_super_admin: isSuperAdmin, user_role: userRole },
        req
      )

      return new Response(JSON.stringify({
        success: true,
        is_admin: isAdmin,
        is_super_admin: isSuperAdmin,
        user_id: authResult.sleeper_user_id,
        user_role: userRole
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (action === 'list_users') {
      // For now, allow access for th0rjc (super admin)
      if (authResult.sleeper_user_id !== '872612101674491904') {
        return new Response(JSON.stringify({
          success: false,
          error: 'Admin access required - only th0rjc can access for now'
        }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // Get all users with their roles using security definer function
      const { data: users, error } = await supabase.rpc('get_all_users')

      if (error) {
        throw new Error(`Failed to list users: ${error.message}`)
      }

      await logSecurityEvent(
        supabase,
        'admin_user_list',
        authResult.sleeper_user_id,
        { users_count: users.length },
        req
      )

      return new Response(JSON.stringify({
        success: true,
        users: users
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (action === 'change_role') {
      if (!target_user_id || !new_role) {
        return new Response(JSON.stringify({
          success: false,
          error: 'target_user_id and new_role are required'
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // Use the secure role change function
      const { data: result, error } = await supabase.rpc('change_user_role', {
        target_sleeper_user_id: target_user_id,
        new_role: new_role,
        reason: reason || 'Role changed via admin panel'
      })

      if (error) {
        await logSecurityEvent(
          supabase,
          'admin_role_change_error',
          authResult.sleeper_user_id,
          { target_user_id, new_role, error: error.message },
          req
        )
        throw new Error(`Role change failed: ${error.message}`)
      }

      const changeResult = result[0]
      
      await logSecurityEvent(
        supabase,
        'admin_role_change_success',
        authResult.sleeper_user_id,
        { 
          target_user_id, 
          old_role: changeResult.old_role, 
          new_role: changeResult.new_role_value,
          reason 
        },
        req
      )

      return new Response(JSON.stringify({
        success: changeResult.success,
        message: changeResult.message,
        old_role: changeResult.old_role,
        new_role: changeResult.new_role_value
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (action === 'get_role_audit') {
      // Check admin permission using direct role lookup
      const { data: currentUserRole } = await supabase.rpc('get_user_role', {
        target_sleeper_user_id: authResult.sleeper_user_id
      })
      const isAdmin = currentUserRole === 'admin' || currentUserRole === 'super_admin'
      
      if (!isAdmin) {
        return new Response(JSON.stringify({
          success: false,
          error: 'Admin access required'
        }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // Get role change audit log
      const { data: auditLog, error } = await supabase
        .from('admin_role_changes')
        .select(`
          *,
          target_user:app_users!target_user_id(sleeper_username, display_name),
          changed_by_user:app_users!changed_by_user_id(sleeper_username, display_name)
        `)
        .order('created_at', { ascending: false })
        .limit(50)

      if (error) {
        throw new Error(`Failed to get audit log: ${error.message}`)
      }

      await logSecurityEvent(
        supabase,
        'admin_audit_access',
        authResult.sleeper_user_id,
        { records_count: auditLog.length },
        req
      )

      return new Response(JSON.stringify({
        success: true,
        audit_log: auditLog
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Default: show available actions
    return new Response(JSON.stringify({
      success: true,
      message: 'Admin management ready',
      available_actions: {
        check_admin_status: 'Check if current user is admin',
        list_users: 'List all users with roles (admin only)',
        change_role: 'Change user role (admin only)',
        get_role_audit: 'Get role change audit log (admin only)'
      },
      role_types: ['user', 'admin', 'super_admin']
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error: any) {
    console.error('❌ Error in admin-management function:', error)
    
    // 🔐 AUDIT: Error occurred
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const supabase = createClient(supabaseUrl, supabaseKey)
      
      await logSecurityEvent(
        supabase,
        'admin_management_error',
        null,
        { error: error?.message || 'Unknown error', function: 'admin-management' },
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

/* To invoke locally:

  1. Check admin status:
  curl -X POST 'http://127.0.0.1:54321/functions/v1/admin-management' \
    -H 'Authorization: Bearer JWT_TOKEN' \
    -H 'Content-Type: application/json' \
    -d '{"action": "check_admin_status"}'

  2. List all users (admin only):
  curl -X POST 'http://127.0.0.1:54321/functions/v1/admin-management' \
    -H 'Authorization: Bearer JWT_TOKEN' \
    -H 'Content-Type: application/json' \
    -d '{"action": "list_users"}'

  3. Change user role (admin only):
  curl -X POST 'http://127.0.0.1:54321/functions/v1/admin-management' \
    -H 'Authorization: Bearer JWT_TOKEN' \
    -H 'Content-Type: application/json' \
    -d '{
      "action": "change_role",
      "target_user_id": "872612101674491904",
      "new_role": "admin",
      "reason": "Promoted to admin"
    }'

*/