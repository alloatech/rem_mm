import "jsr:@supabase/functions-js/edge-runtime.d.ts"

console.log("test-simple function loaded")

Deno.serve(async (req) => {
  console.log("🚀 Simple test function called")
  
  return new Response(JSON.stringify({
    success: true,
    message: "Simple test working"
  }), {
    headers: { 'Content-Type': 'application/json' }
  })
})