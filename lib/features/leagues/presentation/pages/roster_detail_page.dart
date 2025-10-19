import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/core/theme/elevated_containers.dart';
import 'package:rem_mm/core/theme/gradient_background.dart';
import 'package:rem_mm/core/widgets/sleeper_avatar.dart';
import 'package:rem_mm/features/leagues/domain/roster.dart';
import 'package:rem_mm/features/players/domain/player.dart';
import 'package:rem_mm/features/players/presentation/providers/players_providers.dart';

class RosterDetailPage extends ConsumerWidget {
  final Roster roster;

  const RosterDetailPage({super.key, required this.roster});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Convert player IDs list to a stable string key to avoid infinite loop
    final playerIdsKey = roster.playerIds.join(',');
    final playersAsync = ref.watch(rosterPlayersProvider(playerIdsKey));

    return Scaffold(
      appBar: AppBar(title: Text(roster.shortName)),
      body: GradientBackground(
        child: playersAsync.when(
          data: (players) {
            // Create lookup map for quick access
            final playerMap = {for (var p in players) p.playerId: p};

            // Split players into categories
            final starterPlayers = roster.starters
                .map((id) => playerMap[id])
                .where((p) => p != null)
                .cast<Player>()
                .toList();

            final benchPlayers = roster.reserves
                .map((id) => playerMap[id])
                .where((p) => p != null)
                .cast<Player>()
                .toList();

            final irPlayers = roster.taxi
                .map((id) => playerMap[id])
                .where((p) => p != null)
                .cast<Player>()
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Team header
                ElevatedHeader(
                  child: Row(
                    children: [
                      SleeperAvatar(
                        avatarUrl: roster.avatarUrl,
                        fallbackText: roster.shortName,
                        radius: 32,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              roster.shortName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                SleeperAvatar(
                                  avatarId: roster.avatarId,
                                  fallbackText: roster.ownerDisplayName ?? 'U',
                                  radius: 10,
                                  backgroundColor: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  roster.ownerDisplayName ?? 'unknown owner',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Stats
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${roster.playerIds.length}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'players',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Starters
                _buildSection(
                  context,
                  title: 'starters',
                  icon: Icons.star,
                  iconColor: Colors.amber,
                  players: starterPlayers,
                  emptyMessage: 'no starters set',
                ),
                const SizedBox(height: 16),

                // Bench
                _buildSection(
                  context,
                  title: 'bench',
                  icon: Icons.event_seat,
                  iconColor: Colors.blue,
                  players: benchPlayers,
                  emptyMessage: 'no bench players',
                ),
                const SizedBox(height: 16),

                // IR/Taxi
                if (irPlayers.isNotEmpty)
                  _buildSection(
                    context,
                    title: 'IR/taxi squad',
                    icon: Icons.local_hospital,
                    iconColor: Colors.red,
                    players: irPlayers,
                    emptyMessage: 'no IR players',
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('error loading players: $error'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Player> players,
    required String emptyMessage,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${players.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Players list
        if (players.isEmpty)
          ElevatedCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  emptyMessage,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          ...players.map((player) => _buildPlayerCard(context, player)),
      ],
    );
  }

  Widget _buildPlayerCard(BuildContext context, Player player) {
    final theme = Theme.of(context);

    return ElevatedCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Position badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPositionColor(player.position),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        player.position ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Team logo chip
                    if (player.teamAbbr != null || player.team != null)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.network(
                            'https://sleepercdn.com/images/team_logos/nfl/${(player.teamAbbr ?? player.team ?? '').toLowerCase()}.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    if (player.teamAbbr != null || player.team != null)
                      const SizedBox(width: 4),
                    // Team
                    Text(
                      player.teamAbbr ?? player.team ?? 'FA',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (player.number != null) ...[
                      Text(
                        ' • #${player.number}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                if (player.isInjured) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.local_hospital, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          player.injuryStatus ?? 'injured',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Player stats/info with badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Rookie star badge or Experience badge
              if (player.yearsExp != null) ...[
                if (player.yearsExp == 0)
                  // Rookie: Star shape with R layered on top
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Layer 1: Yellow star icon as background
                        Icon(Icons.star, size: 32, color: Colors.amber.shade400),
                        // Layer 2: Dark "R" text on top
                        Text(
                          'R',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey.shade900
                                : Colors.grey.shade800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Experience badge - compact with "y" suffix
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade600, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${player.yearsExp}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'y',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
              ],
              if (player.age != null)
                Text(
                  'age ${player.age}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPositionColor(String? position) {
    switch (position?.toUpperCase()) {
      case 'QB':
        return Colors.red.shade700;
      case 'RB':
        return Colors.green.shade700;
      case 'WR':
        return Colors.blue.shade700;
      case 'TE':
        return Colors.orange.shade700;
      case 'K':
        return Colors.purple.shade700;
      case 'DEF':
        return Colors.brown.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
