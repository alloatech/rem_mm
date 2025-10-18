rem_mmRoster Evaluation Model Mastermind (rem_mm) is an AI-powered fantasy football assistant designed to provide expert-level analysis and recommendations for your Sleeper fantasy football leagues. It acts as your personal AI "Assistant GM," leveraging Google Gemini to help you make smarter roster decisions, identify sleeper players, and win your league.Core ArchitectureThe application is built on a modern, scalable architecture using a Flutter frontend and a Supabase backend. The core logic for AI interaction is handled through a Retrieval-Augmented Generation (RAG) pattern, ensuring that the AI has relevant, up-to-date context without being overwhelmed by large data files.graph TD
    subgraph Frontend
        A[Flutter App]
    end

    subgraph Backend (Supabase)
        B[Auth]
        C[Edge Function: get-fantasy-advice]
        D[Postgres w/ pgvector<br>(Player Embeddings)]
        E[Scheduled Function<br>(Daily Data Ingestion)]
    end

    subgraph External Services
        F[Google Gemini API]
        G[Sleeper API]
    end

    A -- User Prompt --> C
    C -- Generates Embedding --> F
    C -- Similarity Search --> D
    D -- Returns Relevant Players --> C
    C -- Augmented Prompt --> F
    F -- Final Answer --> C
    C -- Returns Final Answer --> A

    E -- Calls API Daily --> G
    E -- Generates Embeddings --> F
    E -- Stores Data & Embeddings --> D

    A -- Authenticates User --> B
Tech StackFrontend: FlutterBackend-as-a-Service (MBaaS): SupabaseDatabase: Supabase Postgres with pgvector extensionBackend Logic: Supabase Edge Functions (Deno - TypeScript)AI Model: Google Gemini (Pro & Embedding models)External Data Source: Sleeper APIDetailed Data Flow (RAG Pattern)The key to this architecture is how we handle the massive 5MB players.json file from the Sleeper API. We do not pass this file to Gemini. Instead, we pre-process and store it in a searchable format.1. Data Ingestion & Embedding (Automated Daily)A Scheduled Supabase Function (daily-data-ingestion) runs automatically once a day to keep our player data fresh.Fetch: The function calls the Sleeper API's /players/nfl endpoint to get the complete list of all players.Chunk: It processes the JSON, breaking it down into smaller, meaningful chunks. A natural chunk is a single player's data, formatted into a clean string (e.g., "Player: Patrick Mahomes, Position: QB, Team: KC, Status: Active").Embed: For each player chunk, it calls the Gemini Embeddings API (embedding-001) to convert the text into a numerical vector (an embedding). This vector represents the semantic meaning of the player's data.Store: It stores this information—the player's ID, the text chunk, and the embedding vector—in a Supabase Postgres table named player_embeddings.2. User Query Flow (On-Demand)When a user asks a question in the Flutter app, the following happens:Invoke: The Flutter app calls the main Supabase Edge Function (get-fantasy-advice), sending the user's plain-text prompt.Query Embedding: The Edge Function takes the user's prompt (e.g., "Who are some good waiver wire QBs with high upside?") and calls the Gemini Embeddings API to generate a vector for this question.Retrieve (Similarity Search): It uses this new vector to perform a similarity search against the player_embeddings table in pgvector. This efficiently retrieves the top N most relevant player chunks from our database whose meaning is closest to the user's question.Augment: The function constructs a new, "augmented" prompt. This prompt includes the crucial context retrieved from the database, along with the user's original question.Example Augmented Prompt:Context:
- Player: Jordan Love, Position: QB, Team: GB...
- Player: C.J. Stroud, Position: QB, Team: HOU...
- Player: Anthony Richardson, Position: QB, Team: IND...

Question: Who are some good waiver wire QBs with high upside?

Based on the context provided, answer the user's question.
Generate: The Edge Function sends this smaller, highly relevant augmented prompt to the main Gemini Pro model (generateContent).Return: Gemini generates a final, context-aware answer, which the function passes back to the Flutter app for display.This RAG pattern ensures that Gemini has the precise information it needs to answer questions accurately without hallucinating, all while keeping API calls fast and within token limits.