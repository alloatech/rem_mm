import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/core/theme/elevated_containers.dart';
import 'package:rem_mm/core/theme/gradient_background.dart';
import 'package:rem_mm/features/leagues/domain/league.dart';
import 'package:rem_mm/features/leagues/presentation/providers/leagues_providers.dart';
import 'package:rem_mm/features/leagues/presentation/widgets/roster_card.dart';

class LeagueDetailPage extends ConsumerWidget {
  final League league;

  const LeagueDetailPage({super.key, required this.league});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rostersAsync = ref.watch(leagueRostersProvider(league.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(league.leagueName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(leagueRostersProvider(league.id));
            },
          ),
        ],
      ),
      body: GradientBackground(
        child: rostersAsync.when(
          data: (rosters) {
            if (rosters.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('no teams found', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'sync your league to see teams',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // Sort: current user first, then by roster ID
            final sortedRosters = [...rosters]
              ..sort((a, b) {
                if (a.isCurrentUser && !b.isCurrentUser) return -1;
                if (!a.isCurrentUser && b.isCurrentUser) return 1;
                return a.sleeperRosterId.compareTo(b.sleeperRosterId);
              });

            return Column(
              children: [
                // League info header with elevation and shadow
                ElevatedHeader(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${league.season} season • ${rosters.length} teams',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (league.leagueType != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          league.leagueType!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Rosters list
                Expanded(
                  child: ListView.builder(
                    itemCount: sortedRosters.length,
                    itemBuilder: (context, index) {
                      final roster = sortedRosters[index];
                      return RosterCard(
                        roster: roster,
                        onTap: () {
                          // TODO: Navigate to roster detail page
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Viewing ${roster.shortName}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    },
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
                Text('error loading teams', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(leagueRostersProvider(league.id)),
                  child: const Text('retry'),
                ),
              ],
            ),
          ),
        ), // End of rostersAsync.when
      ), // End of GradientBackground
    ); // End of Scaffold
  }
}
