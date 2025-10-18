// User Session Management - Create authenticated sessions for Sleeper users
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { logSecurityEvent } from '../_shared/auth.ts'

console.log("user-session function loaded")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { action, sleeper_user_id, email } = await req.json()

    // 🔐 AUDIT: Function entry
    await logSecurityEvent(
      supabase,
      'user_session_enter',
      sleeper_user_id,
      { action, function: 'user-session' },
      req
    )

    if (action === 'create_test_session') {
      console.log(`🔐 Creating test session for Sleeper user: ${sleeper_user_id}`)

      // Check if user exists in app_users
      const { data: appUser, error: appUserError } = await supabase
        .from('app_users')
        .select('*')
        .eq('sleeper_user_id', sleeper_user_id)
        .single()

      if (appUserError || !appUser) {
        return new Response(JSON.stringify({
          success: false,
          error: `Sleeper user ${sleeper_user_id} not found in database. Please sync user first using user-sync function.`
        }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // Generate unique email for this user
      const userEmail = email || `${appUser.sleeper_username}@fantasy.local`

      // Check if auth user already exists
      if (appUser.supabase_user_id) {
        const { data: existingUser } = await supabase.auth.admin.getUserById(appUser.supabase_user_id)
        if (existingUser?.user) {
          console.log('✅ User already has auth session')
          return new Response(JSON.stringify({
            success: true,
            message: 'User already has authentication session',
            user: {
              id: existingUser.user.id,
              email: existingUser.user.email,
              sleeper_user_id: appUser.sleeper_user_id,
              sleeper_username: appUser.sleeper_username
            },
            instructions: 'Use this user ID to generate JWT tokens in your client application'
          }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          })
        }
      }

      // Create new auth user
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email: userEmail,
        password: `fantasy_${sleeper_user_id}!`,
        email_confirm: true,
        user_metadata: {
          sleeper_user_id: sleeper_user_id,
          sleeper_username: appUser.sleeper_username,
          display_name: appUser.display_name,
          created_via: 'user_session_management'
        }
      })

      if (authError) {
        console.error('❌ Auth user creation failed:', authError)
        return new Response(JSON.stringify({
          success: false,
          error: `Failed to create auth user: ${authError.message}`
        }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // Update app_users with supabase_user_id
      const { error: updateError } = await supabase
        .from('app_users')
        .update({ 
          supabase_user_id: authData.user.id,
          email: userEmail 
        })
        .eq('sleeper_user_id', sleeper_user_id)

      if (updateError) {
        console.error('❌ Failed to link auth user:', updateError)
      }

      console.log('✅ Test session created successfully')

      return new Response(JSON.stringify({
        success: true,
        message: 'Test authentication session created',
        user: {
          id: authData.user.id,
          email: authData.user.email,
          sleeper_user_id: sleeper_user_id,
          sleeper_username: appUser.sleeper_username,
          display_name: appUser.display_name
        },
        instructions: {
          next_steps: [
            'Use this user to sign in through Supabase auth in your Flutter app',
            'Or use supabase.auth.signInWithPassword() with the generated credentials',
            'The JWT token from sign-in can then be used with other functions'
          ],
          test_credentials: {
            email: userEmail,
            password: `fantasy_${sleeper_user_id}!`
          }
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (action === 'list_users') {
      // List all users with their auth status
      const { data: users, error } = await supabase
        .from('app_users')
        .select('*')
        .order('created_at', { ascending: false })

      if (error) {
        throw new Error(`Failed to list users: ${error.message}`)
      }

      return new Response(JSON.stringify({
        success: true,
        users: users.map(user => ({
          sleeper_user_id: user.sleeper_user_id,
          sleeper_username: user.sleeper_username,
          display_name: user.display_name,
          has_auth_session: !!user.supabase_user_id,
          email: user.email,
          created_at: user.created_at
        }))
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Default: show available actions
    return new Response(JSON.stringify({
      success: true,
      message: 'User session management ready',
      available_actions: {
        create_test_session: 'Create authentication session for existing Sleeper user',
        list_users: 'List all users and their auth status'
      },
      example_usage: {
        create_session: {
          action: 'create_test_session',
          sleeper_user_id: '872612101674491904',
          email: 'optional@email.com'
        },
        list_users: {
          action: 'list_users'
        }
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error: any) {
    console.error('❌ Error in user-session function:', error)
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

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make sure your Sleeper user exists (use user-sync first if needed)
  3. Create test session:

  curl -X POST 'http://127.0.0.1:54321/functions/v1/user-session' \
    -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    -H 'Content-Type: application/json' \
    -d '{
      "action": "create_test_session", 
      "sleeper_user_id": "872612101674491904",
      "email": "th0rjc@fantasy.local"
    }'

  4. List users:
  curl -X POST 'http://127.0.0.1:54321/functions/v1/user-session' \
    -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    -H 'Content-Type: application/json' \
    -d '{"action": "list_users"}'

*/