// Shared Authentication Utilities for Supabase Edge Functions
// This module provides common auth functions that can be imported by other Edge Functions

// Extract user from JWT token with proper error handling
export async function getCurrentUser(req: Request, supabase: any): Promise<{
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

    if (!appUser) {
      // User exists in Supabase auth but not linked to Sleeper yet
      return {
        user,
        sleeper_user_id: null,
        app_user_id: null,
        error: 'User not linked to Sleeper account yet'
      }
    }

    return {
      user,
      sleeper_user_id: appUser.sleeper_user_id,
      app_user_id: appUser.id
    }

  } catch (error: any) {
    console.error('❌ getCurrentUser error:', error)
    return {
      user: null,
      sleeper_user_id: null,
      app_user_id: null,
      error: `Authentication error: ${error?.message || 'Unknown error'}`
    }
  }
}

// Create a Supabase auth user for a Sleeper user (for development/testing)
export async function createAuthSession(supabase: any, sleeper_user_id: string, email?: string): Promise<{
  user: any | null
  session: any | null
  error?: string
}> {
  try {
    // Generate a unique email if not provided
    const userEmail = email || `sleeper_${sleeper_user_id}@fantasy.local`
    
    console.log(`🔐 Creating auth session for Sleeper user ${sleeper_user_id}`)

    // First check if user already exists in app_users
    const { data: existingAppUser } = await supabase
      .from('app_users')
      .select('supabase_user_id, sleeper_username')
      .eq('sleeper_user_id', sleeper_user_id)
      .single()

    if (existingAppUser?.supabase_user_id) {
      // User already has auth session, try to get it
      const { data: existingAuthUser } = await supabase.auth.admin.getUserById(existingAppUser.supabase_user_id)
      if (existingAuthUser?.user) {
        console.log('✅ Using existing auth session')
        return {
          user: existingAuthUser.user,
          session: null, // We don't have the session token, but user exists
        }
      }
    }

    // Create new Supabase auth user
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: userEmail,
      password: `sleeper_${sleeper_user_id}_temp!`, // Temporary password
      email_confirm: true,
      user_metadata: {
        sleeper_user_id,
        provider: 'sleeper',
        created_via: 'auth_session_helper'
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
      .update({ 
        supabase_user_id: authData.user.id,
        email: userEmail
      })
      .eq('sleeper_user_id', sleeper_user_id)

    if (updateError) {
      console.error('❌ App user update error:', updateError)
      // Don't fail completely, auth user was created successfully
    }

    console.log('✅ Auth session created for user:', authData.user.id)

    return {
      user: authData.user,
      session: authData.session,
    }

  } catch (error: any) {
    console.error('❌ createAuthSession error:', error)
    return {
      user: null,
      session: null,
      error: error?.message || 'Session creation failed'
    }
  }
}

// Generate a JWT token for testing purposes
export async function generateUserToken(supabase: any, userId: string): Promise<{
  token: string | null
  error?: string
}> {
  try {
    // This would typically be done through proper Supabase auth flow
    // For local development, we can use the service role to generate tokens
    
    console.log('🎟️ Generating token for user:', userId)
    
    // In a real app, tokens are generated through sign-in flows
    // This is a placeholder for development
    return {
      token: null,
      error: 'Token generation requires proper auth flow - use Supabase auth.signIn() in client'
    }

  } catch (error: any) {
    return {
      token: null,
      error: error?.message || 'Token generation failed'
    }
  }
}

// Common CORS headers
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Security audit logging
export async function logSecurityEvent(
  supabase: any,
  eventType: string,
  userIdentifier: string | null,
  details: any = {},
  req?: Request
): Promise<void> {
  try {
    const auditData = {
      event_type: eventType,
      user_identifier: userIdentifier || 'anonymous',
      details: JSON.stringify(details),
      ip_address: req?.headers.get('x-forwarded-for') || req?.headers.get('x-real-ip') || null,
      user_agent: req?.headers.get('user-agent') || null
    }

    await supabase
      .from('security_audit')
      .insert(auditData)

  } catch (error) {
    // Don't fail the main function if audit logging fails
    console.error('❌ Audit logging failed:', error)
  }
}

// Helper to create authenticated Supabase client
export function createAuthenticatedClient(useServiceRole = false) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseKey = useServiceRole 
    ? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    : Deno.env.get('SUPABASE_ANON_KEY')!
  
  return { supabaseUrl, supabaseKey }
}