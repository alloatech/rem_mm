# Copilot Instructions for rem_mm

## Project Overview
**rem_mm** (Roster Evaluation Model Mastermind) is an AI-powered fantasy football assistant using a RAG (Retrieval-Augmented Generation) architecture. It provides expert-level analysis for Sleeper fantasy football leagues by combining a Flutter frontend with a Supabase backend and Google Gemini AI.

## Architecture Understanding
- **Frontend**: Flutter app with multi-platform support (iOS, Android, Web, Desktop)
- **Backend**: Supabase (BaaS) with PostgreSQL + pgvector extension for embeddings
- **AI Pipeline**: RAG pattern using Google Gemini (Pro + Embedding models)
- **External API**: Sleeper API for NFL player data
- **Authentication**: Hybrid system - Supabase auth.users + custom app_users with sleeper_user_id linking
- **Authorization**: Three-tier role system (user/admin/super_admin) with comprehensive audit logging
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
Complete backend API with TypeScript/Deno functions:

#### Core RAG System
- `hybrid-fantasy-advice`: Main RAG query handler with cost-optimized embedding system
- `simple-ingestion`: Daily NFL player data ingestion and embedding generation

#### User Management & Authentication
- `user-sync`: Sleeper user registration and league/roster synchronization
- `user-session`: Session management and authentication utilities
- `auth-user`: Authentication helper functions
- `get-auth-token`: JWT token generation for testing

#### Admin Management System
- `admin-management`: Complete role-based access control system
  - User role management (user/admin/super_admin)
  - Admin-only features (list users, change roles, audit logs)
  - Comprehensive security audit logging

### Data Patterns
- **Hybrid RAG Architecture**: Stable embeddings once/season + real-time filters for 120x cost savings
- **Player embeddings** stored in PostgreSQL with pgvector extension (768-dimensional vectors)
- **Similarity search** enables semantic query matching with high relevance
- **Context chunking** keeps prompts within token limits while maintaining relevance
- **Security audit system**: Complete logging across all Edge Functions with user identification
- **Admin role system**: user_role enum (user, admin, super_admin) with audit trail for role changes

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
- Verify embedding model consistency (text-embedding-004)
- Monitor Edge Function logs for query processing errors
- Test similarity search queries directly in Supabase

### Admin System Management
- Use `admin-management` Edge Function for role management
- Check `security_audit` table for comprehensive activity logging
- Verify admin roles using `is_admin()` and `is_super_admin()` functions
- Monitor `admin_role_changes` table for role change audit trail
- Test admin functions with th0rjc user (super_admin) for validation

## Style Guides
- Follow Dart and Flutter style guides
- Prefer dark mode UI designs
- UI needs to be responsive, modern, compact and user-friendly
- Color pallette: #F58031, #32ACE3, #59ba32
- Fonts: Use Google Fonts - 'Roboto Slab' weight 100 for body, 'Raleway' weight 400 for headings

## Dart Coding Guidelines
- Try to use the latest version of stable dart and flutter.  Also - use the most current packages.
- Use null safety features extensively
- Prefer immutable data structures where possible
- Use async/await for all asynchronous operations   
- Prefer importing packages over relative paths
- Leverage supabase_flutter abstractions for database and auth interactions.  Leverage the existing Edge Functions rather than creating new backend logic in the app. Leverage supabase_flutter abstraction for getting realtime data and subscriptions.
- Leverage riverpod for state management and dependency injection.
- Every class should leverage a proper logging mechanism for easier debugging and monitoring. Use a consistent logging package and ensure logs include relevant context information and have various levels depending on the severity of the log message.
- make sure to handle exceptions gracefully and provide meaningful error messages.
- make all status messages clickable and pasteable where applicable to improve user experience.
- the UI should be compact and information-dense while remaining user-friendly. similar to sleeper's UI.
- for UI labels and text I prefer ALL lower case except for I, proper nouns, and acronyms.
