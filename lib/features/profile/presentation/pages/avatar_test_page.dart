import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/profile/presentation/providers/profile_providers.dart';
import 'package:rem_mm/features/profile/presentation/widgets/user_avatar.dart';

class AvatarTestPage extends ConsumerWidget {
  const AvatarTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleeperUserId = ref.watch(currentSleeperUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Avatar Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Current Sleeper User ID: $sleeperUserId'),
            const SizedBox(height: 20),
            const Text('Avatar (should be clickable):'),
            const SizedBox(height: 20),
            const UserAvatar(size: 64),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('🔥 Test button pressed');
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Test button works!')));
              },
              child: const Text('Test Button'),
            ),
            const SizedBox(height: 20),
            if (sleeperUserId != null) ...[
              // Database connectivity test
              Consumer(
                builder: (context, ref, child) {
                  final testAsync = ref.watch(testUserLookupProvider(sleeperUserId));
                  return testAsync.when(
                    data: (result) => Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Database Test Results:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Success: ${result['success']}'),
                          Text('User Exists: ${result['user_exists']}'),
                          Text('Query ID: ${result['sleeper_user_id_query']}'),
                          if (result['raw_data'] != null)
                            Text(
                              'Raw Data: ${result['raw_data'].toString().substring(0, 100)}...',
                            ),
                          if (result['error'] != null)
                            Text(
                              'Error: ${result['error']}',
                              style: TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                    loading: () => const Text('Testing database...'),
                    error: (error, stack) =>
                        Text('Test failed: $error', style: TextStyle(color: Colors.red)),
                  );
                },
              ),
              const SizedBox(height: 20),
              Consumer(
                builder: (context, ref, child) {
                  final profileAsync = ref.watch(
                    currentUserProfileProvider(sleeperUserId),
                  );
                  return profileAsync.when(
                    data: (profile) => Column(
                      children: [
                        Text('Profile loaded: ${profile?.sleeperUsername ?? 'null'}'),
                        if (profile != null)
                          Text('Display name: ${profile.displayName ?? 'Not set'}'),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stack) => Column(
                      children: [
                        Text(
                          'Profile error: $error',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(currentUserProfileProvider(sleeperUserId)),
                          child: const Text('Retry Profile Load'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
