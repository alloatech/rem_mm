import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/core/widgets/sleeper_avatar.dart';
import 'package:rem_mm/features/auth/presentation/pages/sleeper_link_page.dart';
import 'package:rem_mm/features/auth/presentation/providers/auth_providers.dart';
import 'package:rem_mm/features/leagues/presentation/pages/league_detail_page.dart';
import 'package:rem_mm/features/leagues/presentation/providers/leagues_providers.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sleeperUserIdAsync = ref.watch(currentSleeperUserIdProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: sleeperUserIdAsync.when(
            data: (sleeperUserId) {
              if (sleeperUserId == null) {
                return const Center(child: Text('no user logged in'));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'my leagues',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Leagues list
                  Expanded(
                    child: ref
                        .watch(userLeaguesProvider)
                        .when(
                          data: (leagues) {
                            if (leagues.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.sports_football,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'no leagues found',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'link your sleeper account to see leagues',
                                      style: TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => const SleeperLinkPage(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.link),
                                      label: const Text('link sleeper account'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: leagues.length,
                              itemBuilder: (context, index) {
                                final league = leagues[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              LeagueDetailPage(league: league),
                                        ),
                                      );
                                    },
                                    leading: league.avatar != null
                                        ? SleeperAvatar(
                                            avatarId: league.avatar!,
                                            radius: 20,
                                          )
                                        : const Icon(Icons.shield, size: 40),
                                    title: Text(
                                      league.leagueName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${league.season} season • ${league.totalRosters ?? 0} teams',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (error, stack) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'error loading leagues',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.toString(),
                                  style: const TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => ref.invalidate(userLeaguesProvider),
                                  child: const Text('retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('error loading user data', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(currentSleeperUserIdProvider),
                    child: const Text('retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
