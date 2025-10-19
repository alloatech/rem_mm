import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  /// Get current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    String? sleeperUsername,
    String? sleeperUserId,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        if (sleeperUsername != null) 'sleeper_username': sleeperUsername,
        if (sleeperUserId != null) 'sleeper_user_id': sleeperUserId,
      },
    );

    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Register user with Sleeper info after successful auth
  Future<Map<String, dynamic>> registerWithSleeper({
    required String sleeperUserId,
    required String sleeperUsername,
  }) async {
    // Get the current auth token
    final session = currentSession;
    final user = currentUser;

    print('DEBUG: Current user: ${user?.id}');
    print('DEBUG: Current session: ${session != null}');

    if (session == null || user == null) {
      throw Exception('No active session. Please sign in first.');
    }

    print('DEBUG: Session access token: ${session.accessToken.substring(0, 50)}...');
    print('DEBUG: Session user ID: ${session.user.id}');

    final response = await _supabase.functions.invoke(
      'user-sync',
      body: {
        'action': 'register_user',
        'sleeper_user_id': sleeperUserId,
        'sleeper_username': sleeperUsername,
      },
    );

    print('DEBUG: user-sync response status: ${response.status}');
    print('DEBUG: user-sync response data: ${response.data}');

    if (response.data == null) {
      throw Exception('No response data received from user-sync');
    }

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to register with Sleeper');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Get user's sleeper_user_id from app_users table
  Future<String?> getCurrentUserSleeperUserId() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('app_users')
          .select('sleeper_user_id')
          .eq('supabase_user_id', user.id)
          .maybeSingle();

      return response?['sleeper_user_id'] as String?;
    } catch (e) {
      print('Error fetching sleeper_user_id: $e');
      return null;
    }
  }

  /// Check if user is linked to Sleeper account
  Future<bool> isLinkedToSleeper() async {
    final sleeperUserId = await getCurrentUserSleeperUserId();
    return sleeperUserId != null;
  }
}
