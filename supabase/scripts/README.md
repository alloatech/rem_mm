# Supabase Scripts

This directory contains utility scripts for testing and interacting with Supabase Edge Functions.

## Test Scripts

### `test_gemini.ts`
Tests Gemini API connectivity for both text generation (Gemini Pro) and embedding generation.

**Usage:**
```bash
cd supabase/scripts
deno run --allow-net --allow-env test_gemini.ts
```

**Requirements:**
- `GEMINI_API_KEY` environment variable must be set

### `test_rag.ts`
Basic test script for the RAG pipeline functionality.

**Usage:**
```bash
cd supabase/scripts  
deno run --allow-net test_rag.ts
```

## Running Tests

These scripts are designed to be run with Deno and test the functionality of the Supabase Edge Functions and external API integrations.

Make sure you have the necessary environment variables set before running the tests.