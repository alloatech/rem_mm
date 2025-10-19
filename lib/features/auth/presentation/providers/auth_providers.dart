import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/auth/data/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});

// Current user provider - watches auth state changes
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((authState) => authState.session?.user);
});

// Auth state stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user's sleeper_user_id provider (replaces the hardcoded one)
final currentSleeperUserIdProvider = FutureProvider<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUserSleeperUserId();
});

// Is user linked to Sleeper provider (can be invalidated)
final isLinkedToSleeperProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final isLinked = await authService.isLinkedToSleeper();
  print('DEBUG: isLinkedToSleeperProvider - isLinked: $isLinked');
  return isLinked;
});

// Combined auth status provider - checks both auth state and Sleeper linking
final authStatusProvider = StreamProvider<AuthStatus>((ref) async* {
  // Watch the auth state stream
  final authService = ref.watch(authServiceProvider);

  await for (final authState in authService.authStateChanges) {
    print('DEBUG: authStatusProvider - received auth state update');

    final user = authState.session?.user;

    if (user == null) {
      print('DEBUG: authStatusProvider - user is null, yielding unauthenticated');
      yield AuthStatus.unauthenticated;
      continue;
    }

    print('DEBUG: authStatusProvider - user: ${user.id}');

    // Check if user has Sleeper ID
    try {
      final isLinked = await ref.read(isLinkedToSleeperProvider.future);
      final status = isLinked
          ? AuthStatus.authenticatedAndLinked
          : AuthStatus.authenticatedNotLinked;

      print('DEBUG: authStatusProvider - isLinked: $isLinked, status: $status');
      yield status;
    } catch (e) {
      print('DEBUG: authStatusProvider - error checking link status: $e');
      yield AuthStatus.authenticatedNotLinked;
    }
  }
});

enum AuthStatus { unauthenticated, authenticatedNotLinked, authenticatedAndLinked }
