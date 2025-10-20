import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/auth/presentation/pages/login_page.dart';
import 'package:rem_mm/features/auth/presentation/pages/sleeper_link_page.dart';
import 'package:rem_mm/features/auth/presentation/providers/auth_providers.dart';
import 'package:rem_mm/features/navigation/main_navigation_page.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatusAsync = ref.watch(authStatusProvider);

    return authStatusAsync.when(
      data: (authStatus) {
        switch (authStatus) {
          case AuthStatus.unauthenticated:
            return const LoginPage();
          case AuthStatus.authenticatedNotLinked:
            return const SleeperLinkPage();
          case AuthStatus.authenticatedAndLinked:
            return const MainNavigationPage();
        }
      },
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading...', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Authentication Error',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(authStatusProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
