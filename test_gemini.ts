// Test script to verify Gemini API connectivity
// Run with: deno run --allow-net --allow-env test_gemini.ts

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');

if (!GEMINI_API_KEY) {
  console.error('❌ GEMINI_API_KEY not found in environment');
  Deno.exit(1);
}

console.log('🧪 Testing Gemini API connectivity...');

// Test Gemini Pro (Text Generation)
async function testGeminiPro() {
  try {
    console.log('\n📝 Testing Gemini Pro (Text Generation)...');
    
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [{
          parts: [{
            text: "Give me a one-sentence fantasy football tip."
          }]
        }]
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${await response.text()}`);
    }

    const data = await response.json();
    const advice = data.candidates?.[0]?.content?.parts?.[0]?.text;
    
    if (advice) {
      console.log('✅ Gemini Pro working!');
      console.log('💡 Sample advice:', advice.trim());
    } else {
      console.log('❌ Unexpected response format:', data);
    }
  } catch (error) {
    console.error('❌ Gemini Pro test failed:', error.message);
  }
}

// Test Gemini Embedding (Vector Generation)
async function testGeminiEmbedding() {
  try {
    console.log('\n🔢 Testing Gemini Embedding (Vector Generation)...');
    
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: "models/embedding-001",
        content: {
          parts: [{
            text: "Player: Josh Allen, Position: QB, Team: BUF, Status: Active"
          }]
        }
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${await response.text()}`);
    }

    const data = await response.json();
    const embedding = data.embedding?.values;
    
    if (embedding && Array.isArray(embedding)) {
      console.log('✅ Gemini Embedding working!');
      console.log(`📊 Vector dimensions: ${embedding.length}`);
      console.log(`🔢 Sample values: [${embedding.slice(0, 5).map(v => v.toFixed(4)).join(', ')}...]`);
    } else {
      console.log('❌ Unexpected response format:', data);
    }
  } catch (error) {
    console.error('❌ Gemini Embedding test failed:', error.message);
  }
}

// Run tests
async function runTests() {
  await testGeminiPro();
  await testGeminiEmbedding();
  console.log('\n🎯 Next: Update your .env file with the API key and run the RAG pipeline!');
}

runTests();