import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/auth/presentation/providers/auth_providers.dart';
import 'package:rem_mm/features/profile/presentation/providers/profile_providers.dart';
import 'package:rem_mm/features/profile/presentation/widgets/user_avatar.dart';

class AvatarTestPage extends ConsumerWidget {
  const AvatarTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleeperUserIdAsync = ref.watch(currentSleeperUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Avatar Test')),
      body: sleeperUserIdAsync.when(
        data: (sleeperUserId) {
          if (sleeperUserId == null) {
            return const Center(child: Text('No user logged in'));
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'User Avatar Test',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Different sizes
                  Text(
                    'Different Sizes:',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      UserAvatar(size: 24),
                      UserAvatar(size: 32),
                      UserAvatar(size: 48),
                      UserAvatar(size: 64),
                      UserAvatar(size: 80),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Test profile data
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text('Test User Data for: $sleeperUserId'),
                        const SizedBox(height: 16),
                        const Text('Loading test data...'),
                        const CircularProgressIndicator(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Profile data section
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Current User Profile:',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Consumer(
                          builder: (context, ref, child) {
                            final profileAsync = ref.watch(
                              currentUserProfileProvider(sleeperUserId),
                            );

                            return profileAsync.when(
                              data: (profile) => Column(
                                children: [
                                  Text(
                                    'Profile loaded: ${profile?.sleeperUsername ?? 'null'}',
                                  ),
                                  Text('Display Name: ${profile?.displayName ?? 'null'}'),
                                  Text('Avatar URL: ${profile?.avatarUrl ?? 'null'}'),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => ref.invalidate(
                                      currentUserProfileProvider(sleeperUserId),
                                    ),
                                    child: const Text('Refresh Profile'),
                                  ),
                                ],
                              ),
                              loading: () => const CircularProgressIndicator(),
                              error: (error, stack) => Column(
                                children: [
                                  Text('Error: $error'),
                                  ElevatedButton(
                                    onPressed: () => ref.invalidate(
                                      currentUserProfileProvider(sleeperUserId),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading user data...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Error loading user data'),
              SizedBox(height: 8),
              Text(error.toString()),
            ],
          ),
        ),
      ),
    );
  }
}
