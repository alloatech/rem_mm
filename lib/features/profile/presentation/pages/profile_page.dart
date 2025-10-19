import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/auth/presentation/providers/auth_providers.dart';
import 'package:rem_mm/features/profile/presentation/providers/profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleeperUserIdAsync = ref.watch(currentSleeperUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: sleeperUserIdAsync.when(
        data: (sleeperUserId) {
          if (sleeperUserId == null) {
            return const Center(child: Text('No user logged in'));
          }

          final profileAsync = ref.watch(currentUserProfileProvider(sleeperUserId));

          return profileAsync.when(
            data: (profile) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Profile for: ${profile?.sleeperUsername ?? 'Unknown'}'),
                  Text('Display Name: ${profile?.displayName ?? 'Not set'}'),
                  Text('Email: ${profile?.email ?? 'Not set'}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(currentUserProfileProvider(sleeperUserId)),
                    child: const Text('Refresh Profile'),
                  ),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $error'),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(currentUserProfileProvider(sleeperUserId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading user: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentSleeperUserIdProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
