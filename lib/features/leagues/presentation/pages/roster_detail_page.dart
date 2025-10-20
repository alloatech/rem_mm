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
                      // Stats - Season totals
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Record
                          Text(
                            roster.record,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'record',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Points For
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PF: ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                roster.pointsFor.toStringAsFixed(2),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          // Points Against
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PA: ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                roster.pointsAgainst.toStringAsFixed(2),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.red.shade300,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Player count
                          Text(
                            '${roster.playerIds.length} players',
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
                  icon: Icons.sports_football,
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

                // IR
                if (irPlayers.isNotEmpty)
                  _buildSection(
                    context,
                    title: 'ir',
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
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${players.length})',
                style: theme.textTheme.titleSmall?.copyWith(
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
    final teamCode = (player.teamAbbr ?? player.team ?? '').toUpperCase();
    final logoUrl =
        'https://sleepercdn.com/images/team_logos/nfl/${(teamCode).toLowerCase()}.png';

    return ElevatedCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Team logo column - larger, circular, no white background
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: ClipOval(
                  child: Image.network(
                    logoUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.transparent,
                      child: Icon(Icons.shield, size: 28, color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                teamCode.isNotEmpty ? teamCode : 'FA',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Team code + number inline (we moved logo to the left)
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
                          style: theme.textTheme.titleSmall?.copyWith(
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
                  // Experience badge - matches rookie size
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade600, width: 1),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${player.yearsExp}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'y',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade400,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
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
