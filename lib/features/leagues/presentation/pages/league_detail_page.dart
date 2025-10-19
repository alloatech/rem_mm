import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/core/theme/elevated_containers.dart';
import 'package:rem_mm/core/theme/gradient_background.dart';
import 'package:rem_mm/features/leagues/domain/league.dart';
import 'package:rem_mm/features/leagues/presentation/pages/roster_detail_page.dart';
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${league.season} season • ${rosters.length} teams',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Status badge
                          _buildStatusBadge(theme),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildLeagueStats(theme),
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
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RosterDetailPage(roster: roster),
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

  Widget _buildStatusBadge(ThemeData theme) {
    // Parse status from settings or metadata if available
    final status = _getLeagueStatus();
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Text(
        status,
        style: theme.textTheme.bodySmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildLeagueStats(ThemeData theme) {
    final stats = _extractLeagueStats();

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: stats.map((stat) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(stat.icon, size: 14, color: theme.colorScheme.secondary),
            const SizedBox(width: 4),
            Text(
              stat.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[300],
                fontSize: 12,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _getLeagueStatus() {
    // Use actual status from API if available
    if (league.status != null) {
      return league.status!.replaceAll('_', ' ');
    }

    // Fallback to estimation based on season/date
    final now = DateTime.now();
    final seasonYear = league.season;

    if (now.year < seasonYear) return 'pre-draft';
    if (now.year > seasonYear) return 'complete';
    if (now.month >= 9 && now.month <= 12) return 'in season';
    if (now.month >= 1 && now.month <= 2) return 'playoffs';
    return 'offseason';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in season':
        return Colors.green;
      case 'playoffs':
        return Colors.orange;
      case 'complete':
        return Colors.grey;
      case 'pre-draft':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  List<_LeagueStat> _extractLeagueStats() {
    final stats = <_LeagueStat>[];

    // Debug logging
    print('🔍 League settings: ${league.settings}');
    print('🔍 League status: ${league.status}');
    print('🔍 Scoring settings: ${league.scoringSettings}');

    // Scoring type (from scoring_settings)
    final scoringSettings = league.scoringSettings;
    if (scoringSettings != null) {
      final recPoints = scoringSettings['rec'];
      if (recPoints != null) {
        String scoringType;
        if (recPoints == 1.0 || recPoints == 1) {
          scoringType = 'full ppr';
        } else if (recPoints == 0.5) {
          scoringType = 'half ppr';
        } else if (recPoints == 0.0 || recPoints == 0) {
          scoringType = 'standard';
        } else {
          scoringType = '${recPoints}ppr';
        }
        stats.add(_LeagueStat(Icons.sports_football, scoringType));
        print('✅ Added scoring type: $scoringType');
      }
    }

    // League settings-based stats
    final settings = league.settings;
    print('🔍 Settings object: $settings');
    if (settings != null) {
      final playoffTeams = settings['playoff_teams'] as int?;
      print('🔍 Playoff teams: $playoffTeams');
      if (playoffTeams != null && league.totalRosters != null) {
        stats.add(
          _LeagueStat(Icons.emoji_events, '$playoffTeams/${league.totalRosters} playoff'),
        );
        print('✅ Added playoff stat');
      }

      // Trade deadline
      final tradeDeadline = settings['trade_deadline'] as int?;
      if (tradeDeadline != null && tradeDeadline > 0) {
        stats.add(_LeagueStat(Icons.swap_horiz, 'trades until wk $tradeDeadline'));
        print('✅ Added trade deadline');
      }

      // Waiver budget (FAAB)
      final waiverBudget = settings['waiver_budget'] as int?;
      if (waiverBudget != null && waiverBudget > 0) {
        stats.add(_LeagueStat(Icons.attach_money, '\$$waiverBudget faab'));
        print('✅ Added waiver budget');
      }

      // Keepers
      final maxKeepers = settings['max_keepers'] as int?;
      if (maxKeepers != null && maxKeepers > 0) {
        final keeperText = maxKeepers == 1 ? '1 keeper' : '$maxKeepers keepers';
        stats.add(_LeagueStat(Icons.star, keeperText));
        print('✅ Added keepers');
      }
    } else {
      print('❌ Settings is null!');
    }

    print('📊 Total stats: ${stats.length}');
    return stats;
  }
}

class _LeagueStat {
  final IconData icon;
  final String label;

  _LeagueStat(this.icon, this.label);
}
