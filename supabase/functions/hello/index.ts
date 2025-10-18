Deno.serve(async (req) => {
  return new Response("Hello World", {
    headers: { 'Content-Type': 'text/plain' }
  })
})