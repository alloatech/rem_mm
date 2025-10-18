# Copilot Instructions for rem_mm

## Project Overview
**rem_mm** (Roster Evaluation Model Mastermind) is an AI-powered fantasy football assistant using a RAG (Retrieval-Augmented Generation) architecture. It provides expert-level analysis for Sleeper fantasy football leagues by combining a Flutter frontend with a Supabase backend and Google Gemini AI.

## Architecture Understanding
- **Frontend**: Flutter app with multi-platform support (iOS, Android, Web, Desktop)
- **Backend**: Supabase (BaaS) with PostgreSQL + pgvector extension for embeddings
- **AI Pipeline**: RAG pattern using Google Gemini (Pro + Embedding models)
- **External API**: Sleeper API for NFL player data
- **Data Flow**: Daily ingestion → chunk → embed → store → similarity search → augmented prompts

### Critical RAG Implementation
The core innovation is handling Sleeper's 5MB `players.json` file efficiently:
1. **Daily Ingestion**: Supabase Edge Function (`daily-data-ingestion`) fetches player data
2. **Chunking**: Each player becomes a semantic chunk: "Player: Name, Position: X, Team: Y, Status: Z"
3. **Embedding**: Gemini Embedding API converts chunks to vectors stored in `player_embeddings` table
4. **Query Processing**: User prompts → embedding → pgvector similarity search → augmented context → Gemini Pro

## Key Dependencies & Patterns

### Environment & Code Generation
- **envied**: Secure environment variables (Supabase URL/keys) - requires `.env` file (not committed)
- **build_runner**: Code generation for envied and riverpod
- **Run before development**: `dart run build_runner build` to generate required files

### State Management
- **flutter_riverpod**: Primary state management with provider patterns
- **riverpod_generator**: Code generation for providers (creates `.g.dart` files)

### Backend Integration
- **supabase_flutter**: Primary client for auth, database, and Edge Functions
- **http**: Direct API calls to public endpoints (Sleeper API)

## Development Workflows

### Environment Setup
```bash
# Install dependencies
flutter pub get

# Generate required files (environment configs, riverpod providers)
dart run build_runner build

# For environment variables, create .env file with:
# SUPABASE_URL=your_url
# SUPABASE_ANON_KEY=your_key
```

### Testing
- Basic widget tests in `test/widget_test.dart` (currently placeholder)
- Flutter testing framework with `flutter_test`
- Run tests: `flutter test`

### Building
- Standard Flutter build commands work across platforms
- Profile builds available for performance testing
- Bundle identifiers: `com.example.remMm` (update for production)

## Project-Specific Conventions

### File Organization
- `lib/main.dart`: Entry point (currently contains default Flutter counter app)
- No complex directory structure yet - early development stage
- Generated files (`.g.dart`) should not be manually edited

### Edge Functions (Supabase)
Two critical backend functions (TypeScript/Deno):
- `get-fantasy-advice`: Main query handler for user prompts
- `daily-data-ingestion`: Automated player data refresh

### Data Patterns
- Player embeddings stored in PostgreSQL with pgvector extension
- Similarity search enables semantic query matching
- Context chunking keeps prompts within token limits while maintaining relevance

## Integration Points

### External Services
- **Sleeper API**: `/players/nfl` endpoint for player data (no auth required)
- **Google Gemini**: Two models used (Pro for generation, Embedding for vectors)
- **Supabase**: Authentication, database, Edge Functions, scheduled jobs

### Cross-Platform Considerations
- iOS: Uses CocoaPods, requires Xcode configuration
- Android: Gradle-based builds with Kotlin support
- Desktop: CMake builds for Linux/Windows, Xcode for macOS
- Web: Standard web deployment with manifest.json configuration

## Common Tasks

### Adding New Features
1. Update `pubspec.yaml` dependencies if needed
2. Run `dart run build_runner build` after adding envied/riverpod annotations
3. Consider impact on RAG pipeline for data-related features
4. Test across platforms if using platform-specific APIs

### Backend Changes
- Edge Functions are deployed separately in Supabase dashboard
- Database schema changes require Supabase migrations
- Embedding updates require re-running ingestion process

### Debugging RAG Issues
- Check `player_embeddings` table for data freshness
- Verify embedding model consistency (embedding-001)
- Monitor Edge Function logs for query processing errors
- Test similarity search queries directly in Supabase