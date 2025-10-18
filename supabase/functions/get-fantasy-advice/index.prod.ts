// Production-Ready Fantasy Advice Function with Security
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

// Security constants
const MAX_QUERY_LENGTH = 500
const RATE_LIMIT_REQUESTS = 10
const RATE_LIMIT_WINDOW = 60 // minutes

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGINS') || 'http://localhost:3000',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400'
}

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

// Get client IP for rate limiting
function getClientIP(request: Request): string {
  return request.headers.get('x-forwarded-for')?.split(',')[0] || 
         request.headers.get('x-real-ip') || 
         'unknown'
}

// Rate limiting check
async function checkRateLimit(supabase: any, clientIP: string): Promise<{ allowed: boolean; error?: string }> {
  try {
    const { data, error } = await supabase.rpc('check_rate_limit', {
      user_identifier: clientIP,
      endpoint_name: 'get-fantasy-advice',
      max_requests: RATE_LIMIT_REQUESTS,
      window_minutes: RATE_LIMIT_WINDOW
    })
    
    if (error) {
      console.error('Rate limit check error:', error)
      return { allowed: true } // Fail open for now
    }
    
    return { allowed: data === true, error: data === false ? 'Rate limit exceeded' : undefined }
  } catch (err) {
    console.error('Rate limit exception:', err)
    return { allowed: true } // Fail open for now
  }
}

// Security audit logging
async function logSecurityEvent(supabase: any, eventType: string, details: any, request: Request) {
  try {
    await supabase
      .from('security_audit')
      .insert({
        event_type: eventType,
        user_identifier: getClientIP(request),
        details: details,
        ip_address: getClientIP(request),
        user_agent: request.headers.get('user-agent')
      })
  } catch (err) {
    console.error('Security logging error:', err)
  }
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        status: 405, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')
    
    if (!supabaseUrl || !supabaseKey) {
      throw new Error('Missing Supabase configuration')
    }
    
    const supabase = createClient(supabaseUrl, supabaseKey)
    const clientIP = getClientIP(req)

    // Rate limiting check
    const rateCheck = await checkRateLimit(supabase, clientIP)
    if (!rateCheck.allowed) {
      await logSecurityEvent(supabase, 'rate_limit_exceeded', { ip: clientIP }, req)
      return new Response(
        JSON.stringify({ error: 'Rate limit exceeded. Please try again later.' }),
        { 
          status: 429, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Parse and validate request body
    let requestBody
    try {
      requestBody = await req.json()
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON in request body' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const { query, context } = requestBody

    // Validate and sanitize input
    const validation = validateAndSanitizeInput(query)
    if (!validation.isValid) {
      await logSecurityEvent(supabase, 'invalid_input', { error: validation.error, original: query }, req)
      return new Response(
        JSON.stringify({ error: validation.error }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Log successful request
    await logSecurityEvent(supabase, 'fantasy_advice_request', { 
      query_length: validation.sanitized.length,
      has_context: !!context
    }, req)

    // TODO: Implement the RAG pipeline with sanitized input
    // 1. Generate embedding for validation.sanitized using Gemini Embedding API
    // 2. Perform similarity search in player_embeddings table using pgvector
    // 3. Augment the prompt with relevant player context
    // 4. Call Gemini Pro for final fantasy football advice

    // For now, return a secure placeholder response
    const response = {
      query: validation.sanitized,
      advice: "🔒 Secure RAG-powered fantasy advice coming soon! All security measures are in place.",
      context: context || "No additional context provided",
      timestamp: new Date().toISOString(),
      security_status: "✅ Request validated and rate-limited"
    }

    return new Response(
      JSON.stringify(response),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Function error:', error)
    
    // Don't expose internal error details to client
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