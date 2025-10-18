// Authentication Utility Functions for Supabase Edge Functions
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

console.log("auth-user function loaded")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Extract and verify user from JWT token
async function getCurrentUser(req: Request, supabase: any): Promise<{
  user: any | null
  sleeper_user_id: string | null
  app_user_id: string | null
  error?: string
}> {
  try {
    // Get the authorization header
    const authHeader = req.headers.get('authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return {
        user: null,
        sleeper_user_id: null,
        app_user_id: null,
        error: 'No valid authorization token provided'
      }
    }

    // Extract the JWT token
    const token = authHeader.substring(7) // Remove 'Bearer '

    // Verify the JWT token with Supabase
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      console.log('❌ Auth error:', authError?.message || 'No user found')
      return {
        user: null,
        sleeper_user_id: null,
        app_user_id: null,
        error: authError?.message || 'Invalid or expired token'
      }
    }

    console.log('✅ Authenticated user:', user.id, user.email)

    // Look up the user in our app_users table to get Sleeper info
    const { data: appUser, error: dbError } = await supabase
      .from('app_users')
      .select('id, sleeper_user_id, sleeper_username, display_name')
      .eq('supabase_user_id', user.id)
      .single()

    if (dbError && dbError.code !== 'PGRST116') { // PGRST116 is "no rows found"
      console.error('❌ Database error:', dbError)
      return {
        user,
        sleeper_user_id: null,
        app_user_id: null,
        error: `Database error: ${dbError.message}`
      }
    }

    return {
      user,
      sleeper_user_id: appUser?.sleeper_user_id || null,
      app_user_id: appUser?.id || null
    }

  } catch (error) {
    console.error('❌ getCurrentUser error:', error)
    return {
      user: null,
      sleeper_user_id: null,
      app_user_id: null,
      error: `Authentication error: ${error.message}`
    }
  }
}

// Create an authenticated user session (for testing or manual login)
async function createUserSession(sleeper_user_id: string, email?: string): Promise<{
  user: any | null
  session: any | null
  error?: string
}> {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Generate a unique email if not provided
    const userEmail = email || `sleeper_${sleeper_user_id}@fantasy.local`

    // Create or update Supabase auth user
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: userEmail,
      password: 'temp_password_123!', // This should be changed in production
      email_confirm: true,
      user_metadata: {
        sleeper_user_id,
        provider: 'sleeper'
      }
    })

    if (authError) {
      console.error('❌ Auth creation error:', authError)
      return {
        user: null,
        session: null,
        error: authError.message
      }
    }

    // Update app_users table to link Supabase user to Sleeper user
    const { error: updateError } = await supabase
      .from('app_users')
      .update({ supabase_user_id: authData.user.id })
      .eq('sleeper_user_id', sleeper_user_id)

    if (updateError) {
      console.error('❌ App user update error:', updateError)
    }

    console.log('✅ User session created:', authData.user.id)

    return {
      user: authData.user,
      session: authData.session,
    }

  } catch (error) {
    console.error('❌ createUserSession error:', error)
    return {
      user: null,
      session: null,
      error: error.message
    }
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { action, sleeper_user_id, email } = await req.json()

    if (action === 'create_session') {
      // Create a new user session (for testing/development)
      const result = await createUserSession(sleeper_user_id, email)
      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (action === 'get_current_user') {
      // Get current authenticated user
      const result = await getCurrentUser(req, supabase)
      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Default: show authentication status
    const authResult = await getCurrentUser(req, supabase)
    
    return new Response(JSON.stringify({
      success: true,
      message: 'Authentication utility ready',
      current_user: authResult,
      available_actions: ['get_current_user', 'create_session'],
      timestamp: new Date().toISOString()
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ Error in auth-user function:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  # Check current authentication status
  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/auth-user' \
    --header 'Authorization: Bearer YOUR_JWT_TOKEN' \
    --header 'Content-Type: application/json' \
    --data '{"action": "get_current_user"}'

  # Create a test session for a Sleeper user  
  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/auth-user' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{
      "action": "create_session",
      "sleeper_user_id": "872612101674491904",
      "email": "th0rjc@fantasy.local"
    }'

*/