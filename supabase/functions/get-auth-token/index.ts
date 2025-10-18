// Get Auth Token - Helper function to get JWT tokens for testing
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

console.log("get-auth-token function loaded")

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
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { email, password, sleeper_user_id } = await req.json()

    // Method 1: Sign in with email/password to get JWT token
    if (email && password) {
      console.log(`🔐 Signing in user: ${email}`)
      
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (error) {
        return new Response(JSON.stringify({
          success: false,
          error: `Sign in failed: ${error.message}`
        }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      return new Response(JSON.stringify({
        success: true,
        message: 'Authentication successful',
        auth_data: {
          access_token: data.session?.access_token,
          user: {
            id: data.user?.id,
            email: data.user?.email,
          },
          expires_at: data.session?.expires_at
        },
        usage: {
          curl_example: `curl -X POST "http://localhost:54321/functions/v1/hybrid-fantasy-advice" \\
  -H "Authorization: Bearer ${data.session?.access_token}" \\
  -H "Content-Type: application/json" \\
  -d '{"query": "Who should I start at QB?", "gemini_api_key": "YOUR_KEY"}'`
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Method 2: Look up credentials for Sleeper user
    if (sleeper_user_id) {
      const { data: appUser } = await supabase
        .from('app_users')
        .select('sleeper_username, email')
        .eq('sleeper_user_id', sleeper_user_id)
        .single()

      if (!appUser) {
        return new Response(JSON.stringify({
          success: false,
          error: `Sleeper user ${sleeper_user_id} not found`
        }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      return new Response(JSON.stringify({
        success: true,
        message: 'User credentials found',
        credentials: {
          email: appUser.email,
          password: `fantasy_${sleeper_user_id}!`,
          instructions: 'Use these credentials with the sign-in endpoint to get JWT token'
        },
        next_step: {
          action: 'Sign in to get JWT token',
          curl: `curl -X POST "http://localhost:54321/functions/v1/get-auth-token" \\
  -H "Content-Type: application/json" \\
  -d '{"email": "${appUser.email}", "password": "fantasy_${sleeper_user_id}!"}'`
        }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Default: show usage
    return new Response(JSON.stringify({
      success: true,
      message: 'Authentication token helper',
      available_methods: {
        sign_in: 'Get JWT token with email/password',
        lookup_credentials: 'Get credentials for Sleeper user'
      },
      examples: {
        get_credentials: {
          sleeper_user_id: '872612101674491904'
        },
        sign_in: {
          email: 'th0rjc@fantasy.local',
          password: 'fantasy_872612101674491904!'
        }
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error: any) {
    console.error('❌ Error in get-auth-token function:', error)
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

  1. Get credentials for Sleeper user:
  curl -X POST 'http://127.0.0.1:54321/functions/v1/get-auth-token' \
    -H 'Content-Type: application/json' \
    -d '{"sleeper_user_id": "872612101674491904"}'

  2. Sign in to get JWT token:
  curl -X POST 'http://127.0.0.1:54321/functions/v1/get-auth-token' \
    -H 'Content-Type: application/json' \
    -d '{"email": "th0rjc@fantasy.local", "password": "fantasy_872612101674491904!"}'

*/